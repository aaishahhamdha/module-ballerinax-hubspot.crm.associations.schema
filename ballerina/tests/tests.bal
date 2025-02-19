// Copyright (c) 2025, WSO2 LLC. (http://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ballerina/io;
import ballerina/oauth2;
import ballerina/os;
import ballerina/test;

final boolean isLiveServer = os:getEnv("IS_LIVE_SERVER") == "true";
final string serviceUrl = isLiveServer ? "https://api.hubapi.com/crm/v4/associations" : "http://localhost:9090";

final string clientId = os:getEnv("HUBSPOT_CLIENT_ID");
final string clientSecret = os:getEnv("HUBSPOT_CLIENT_SECRET");
final string refreshToken = os:getEnv("HUBSPOT_REFRESH_TOKEN");

final string fromObjectType = "contacts";
final string toObjectType = "deals";

final string label = "Label";
final string inverseLabel = "InverseLabel";
final string labelName = "LabelName";
final string labelToUpdate = "LabelNew";

final int:Signed32 typeId = 4; //association type id for contact to deals association

//init client
final Client baseClient = check initClient();

isolated function initClient() returns Client|error {
    io:println("Initializing client...");
    if isLiveServer {
        OAuth2RefreshTokenGrantConfig auth = {
            clientId: clientId,
            clientSecret: clientSecret,
            refreshToken: refreshToken,
            credentialBearer: oauth2:POST_BODY_BEARER
        };
        return check new Client({auth}, serviceUrl);
    }
    return check new Client({auth: {token: "test-token"}}, serviceUrl);
}

isolated int:Signed32 createdInverseLabelId = -1;
isolated int:Signed32 createdLabelId = -1;


//Association definition Tests
//Test: Create association definitions
@test:Config {groups: ["live_test", "mock_test"]}
isolated function testCreateAssociationDefinitions() returns error? {
    io:println("Running test: Create association definitions...");
    CollectionResponseAssociationSpecWithLabelNoPaging response =
        check baseClient->/[fromObjectType]/[toObjectType]/labels.post(payload = {
        "label": label,
        "name": labelName,
        "inverseLabel": inverseLabel
    });
    if response.results.length() > 0 {
        lock {
            createdLabelId = response.results[0].typeId;
        }
        lock {
            createdInverseLabelId = response.results[1].typeId;
        }
    }

    test:assertTrue(response.results.length() > 0, msg = "No association definitions were created.");
    test:assertEquals(response.results.length(), 2, msg = "Unexpected behavior on association definition creation.");
    io:println("Test Passed: Created association definitions: " + response.results.length().toString());
}

//Test: Update association definitions
@test:Config {dependsOn: [testCreateAssociationDefinitions], groups: ["live_test", "mock_test"]}
isolated function testUpdateAssociationDefinitions() returns error? {
    io:println("Running test: Update association definitions...");

    int response1StatusCode = -1;
    int response2StatusCode = -1;

    lock {
        var response1 = check baseClient->/[fromObjectType]/[toObjectType]/labels.put(payload = {
            "associationTypeId": createdLabelId,
            "label": labelToUpdate
        });
        response1StatusCode = response1.statusCode;
        io:println("Updated association definition with ID: " + createdLabelId.toString() + " to: " + labelToUpdate);
    }

    lock {
        var response2 = check baseClient->/[fromObjectType]/[toObjectType]/labels.put(payload = {
            "associationTypeId": createdInverseLabelId,
            "label": labelToUpdate
        });
        response2StatusCode = response2.statusCode;
        io:println("Updated inverse association definition with ID: " + createdInverseLabelId.toString() + " to: " + labelToUpdate);
    }

    test:assertTrue(response1StatusCode == 204 || response2StatusCode == 204, msg = "Association label update failed for both createdLabelId and createdInverseLabelId");
}

//Test: Read association definitions
@test:Config {dependsOn: [testCreateAssociationDefinitions], groups: ["live_test", "mock_test"]}
isolated function testGetAssociationDefinitions() returns error? {
    io:println("Running test: Get association definitions...");
    CollectionResponseAssociationSpecWithLabelNoPaging response =
        check baseClient->/[fromObjectType]/[toObjectType]/labels.get();
    test:assertTrue(response.results.length() > 0, msg = "No definitions were returned");
    test:assertEquals(response.results.length(), 2, msg = "Unexpected behavior on association definition retrieval.");
    io:println("Test Passed: Retrieved association definitions: " + response.results.length().toString());
}

//Test: Delete association definitions
@test:Config {dependsOn: [testGetAssociationDefinitions], groups: ["live_test", "mock_test"]}
isolated function testDeleteAssociationDefinitions() returns error? {
    io:println("Running test: Delete association definitions...");
    lock {
        var response1 = check baseClient->/[fromObjectType]/[toObjectType]/labels/[createdLabelId].delete();
        test:assertTrue(response1.statusCode == 204, msg = "Association definition deletion failed");
        io:println("Deleted association definition with ID: " + createdLabelId.toString());
    }
    lock {
        var response2 = check baseClient->/[fromObjectType]/[toObjectType]/labels/[createdInverseLabelId].delete();
        test:assertTrue(response2.statusCode == 204, msg = "Association definition deletion failed");
        io:println("Deleted inverse association definition with ID: " + createdInverseLabelId.toString());
    }
}