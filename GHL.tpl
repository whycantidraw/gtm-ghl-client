___INFO___

{
  "type": "CLIENT",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "GHL",
  "brand": {
    "id": "brand_dummy",
    "displayName": ""
  },
  "description": "",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "CHECKBOX",
    "name": "auto_send",
    "checkboxText": "Automatically forward JSON to CAPI?",
    "simpleValueType": true
  },
  {
    "type": "SELECT",
    "name": "meta_capi_ver",
    "displayName": "Meta API Version",
    "macrosInSelect": true,
    "selectItems": [
      {
        "value": "v19.0",
        "displayValue": "v19.0"
      },
      {
        "value": "v20.0",
        "displayValue": "v20.0"
      },
      {
        "value": "v21.0",
        "displayValue": "v21.0"
      },
      {
        "value": "v22.0",
        "displayValue": "v22.0"
      }
    ],
    "simpleValueType": true
  },
  {
    "type": "SELECT",
    "name": "event_name",
    "displayName": "Meta Event Name",
    "macrosInSelect": false,
    "selectItems": [
      {
        "value": "stage",
        "displayValue": "Stage"
      },
      {
        "value": "pipeline",
        "displayValue": "Pipeline"
      },
      {
        "value": "both",
        "displayValue": "Both"
      }
    ],
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "test_event_code",
    "displayName": "Meta Test Event Code",
    "simpleValueType": true
  },
  {
    "type": "TEXT",
    "name": "ghl_psk",
    "displayName": "Secret Key",
    "simpleValueType": true,
    "canBeEmptyString": true
  }
]


___SANDBOXED_JS_FOR_SERVER___

// Request Functions
const claimRequest = require('claimRequest');
const getRequestPath = require('getRequestPath');
const requestPath = getRequestPath();
const getRequestBody = require('getRequestBody');
const getRequestMethod = require('getRequestMethod');
const getRequestQueryParameters = require('getRequestQueryParameters');
const getRequestHeader = require('getRequestHeader');
const encodeUri = require('encodeUri');

// GHL Container Functions
const runContainer = require('runContainer');
const addEventCallback = require('addEventCallback');
// Response Functions
const returnResponse = require('returnResponse');
const setResponseStatus = require('setResponseStatus');
const setResponseHeader = require('setResponseHeader');
const sendHttpRequest = require('sendHttpRequest');

const logToConsole = require('logToConsole');
const getTimestampMillis = require('getTimestampMillis');
const makeInteger = require('makeInteger');
const sha256Sync = require('sha256Sync');
const getType = require('getType');
const JSON = require('JSON');

// auth
function authenticate(){
  if (data.ghl_psk == getRequestHeader("ghl-psk")){
    return;
  } else {
    setResponseStatus(403);
    setResponseHeader("message", "Forbidden");
    returnResponse();
    return 403;
  }
}

// Hash Function
function hashFunction(input){
  const type = getType(input);
  if(type == 'undefined' || input == 'undefined') {
    return undefined;
  }

  if(input == null){
    return input;
  }
  return sha256Sync(input.trim().toLowerCase(), {outputEncoding: 'hex'});
}

function parseRequest(){
  logToConsole("Parsing the request");
  let params;
  if(getRequestMethod() == 'POST'){
    params = JSON.parse(getRequestBody());
  } else{
    params = getRequestQueryParameters();
  }
  return params;
}

function sendRequest(headers, wrapper, uri){
  sendHttpRequest(uri, {
    headers: headers,
    method: "POST",
    timeout: 500,
  }, JSON.stringify(wrapper))
  .then((result) => {
    logToConsole("Response: ", result.statusCode);
  });
}

function compileMetaRequest(eventModel){
  logToConsole("Compiling CAPI Data...");
  if (eventModel.test_hook) {
    logToConsole("Firing test event to: " + eventModel.test_hook);
    eventModel.meta_url = eventModel.test_hook;
  } else {
    const metaEndpoint = "https://graph.facebook.com/";
    const metaCapiVer = data.meta_capi_ver;
    eventModel.meta_url = metaEndpoint + metaCapiVer + "/" + eventModel.meta_pixel + "/events?access_token=" + eventModel.meta_token;
  }

  const packetData = {
      "event_name": eventModel.stage_name,
      "event_time": eventModel.event_time,
      "action_source": eventModel.action_source,
      "user_data": {}
  };
  if (data.event_name === "pipeline") {
    packetData.event_name = eventModel.pipeline_name;
  } else if (data.event_name === "both") {
    packetData.event_name = eventModel.pipeline_name + "-" + eventModel.stage_name;
  }
  if(eventModel.em) packetData.user_data.em = eventModel.em;
  if(eventModel.ph) packetData.user_data.ph = eventModel.ph;
  if(eventModel.ip) packetData.user_data.client_ip_address = eventModel.ip;
  if(eventModel.fbp) packetData.user_data.fbp = eventModel.fbp;
  if(eventModel.fbc) packetData.user_data.fbc = eventModel.fbc;
  if(eventModel.uid) packetData.user_data.external_id = eventModel.uid;
  const headers = {
      "Content-Type": "application/json",
      "Cache-Control": "no-cache"
  };
  
    logToConsole("Sending CAPI Data...");
    const wrapper = {"data": [packetData]};
    if (data.test_event_code && data.test_event_code != ""){
      wrapper.test_event_code = data.test_event_code;
    }
    sendRequest(headers, wrapper, encodeUri(eventModel.meta_url));
}

function runMain(params){
    // format the event data for use
    logToConsole("Preparing the event model");
    const now = getTimestampMillis();
    const eventModel = {};
  
    eventModel.event_name = params.customData.event_name;
    eventModel.event_time = makeInteger(now/1000);
    eventModel.contact = params.contact;
    
    //process custom data
    if (params.customData.stage_name) {
      eventModel.stage_name = params.customData.stage_name;
    }
    if (params.customData.pipeline_name) {
      eventModel.pipeline_name = params.customData.pipeline_name;
    }
    if (params.customData.action_source) {
      eventModel.action_source = params.customData.action_source;
    } else {
      eventModel.action_source = "other";
    }
  
    //platform specifics
    if (params.customData.platform) eventModel.platforms = params.customData.platform;
    if (params.customData.meta_id) eventModel.meta_pixel = params.customData.meta_id;
    if (params.customData.meta_token) eventModel.meta_token = params.customData.meta_token;
   
    // PII
    if(params.customData.em) {
      eventModel.em = hashFunction(params.customData.em);
    }
    if(params.customData.ph) {
      eventModel.ph = hashFunction(params.customData.ph);
    }
    if (params.customData.uid) {
      eventModel.uid = params.customData.uid;
    }
    if (params.contact && params.contact.lastAttributionSource) {
      if (params.contact.lastAttributionSource.fbc) {
       eventModel.fbc = params.contact.lastAttributionSource.fbc;
      } else if (params.contact.attributionSource.fbc) {
       eventModel.fbc = params.contact.attributionSource.fbc;
      }
      if (params.contact.lastAttributionSource.fbp) {
        eventModel.fbp = params.contact.lastAttributionSource.fbp;
      } else if(params.contact.attributionSource.fbp) {
        eventModel.fbp = params.contact.attributionSource.fbp;
      }
      if (params.contact.lastAttributionSource.ip) {
        eventModel.ip = params.contact.lastAttributionSource.ip;
      } else if(params.contact.attributionSource.ip) {
        eventModel.ip = params.contact.attributionSource.ip;
      }
    }    
    if (params.dummy_uri) {
      eventModel.test_hook = params.dummy_uri;
    }

    if (params.customData.platform_meta && params.customData.platform_meta === 'true' && data.auto_send == "true"){
      compileMetaRequest(eventModel);
    } else if (params.customData.platform_meta && params.customData.platform_meta === 'true' && data.auto_send != true) {
      logToConsole("Auto send CAPI turned off, please use the relevant tag.");
    }
    
    runContainer(eventModel);
    
      setResponseStatus(200);
      setResponseHeader("message", "client ran successfully!");
      returnResponse();
}

// Claim request
if (requestPath === '/gohighlevel') {
  logToConsole("Process workflow request from GHL");
  claimRequest();
  if (authenticate() === 403){
    return "Authentication Failed";
  }
  const params = parseRequest();
  runMain(params);
} else if (requestPath === '/gohighlevel/testing') {
  logToConsole("Process Test Unit");
  claimRequest();
  const params = parseRequest();
  if (params.unit_test_key === data.test_event_code) {
    runMain(params);
    return "UnitTest1";
  } else {
    return 403; 
  }
}


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_request",
        "versionId": "1"
      },
      "param": [
        {
          "key": "requestAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "headerAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queryParameterAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "read_event_metadata",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "run_container",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "return_response",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_response",
        "versionId": "1"
      },
      "param": [
        {
          "key": "writeResponseAccess",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "writeHeaderAccess",
          "value": {
            "type": 1,
            "string": "specific"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://graph.facebook.com/*"
              },
              {
                "type": 1,
                "string": "https://webhook.site/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Meta
  code: |
    //https://www.simoahava.com/analytics/writing-tests-for-custom-templates-google-tag-manager/

    mock('getRequestPath', '/gohighlevel/testing');
    mock('getRequestMethod', 'POST');
    //mock('getRequestBody', encodedRequestData);
    mock('getRequestBody', requestBody);

    const test = runCode(mockData);
    assertThat(test).isEqualTo('UnitTest1');
setup: |-
  const mockData = {
    event_name: "both",
    auto_send: "true",
    test_event_code: "TEST38778",
    ghl_psk: "TEST38778",
    meta_capi_ver: "v19.0"
  };

  const requestBody = '{"contact_id":"ItwpBFnGcgcmNzx5jRrP","first_name":"Fname","last_name":"Lname","full_name":"Fname Lname","email":"test@email.com","tags":"","country":"AU","date_created":"2022-11-10T03:59:18.982Z","contact_source":"internal - testing","full_address":"","contact_type":"lead","opportunity_name":"Fname Lname","status":"open","opportunity_source":"internal - testing","source":"internal - testing","pipleline_stage":"New Leads","pipeline_id":"uNjYxt5aqbSaxe6hxxxx","id":"Dkje7AzwivlF1d2txxxx","pipeline_name":"Doomsday Funnel","location": {"name":"Testing","address":"TestAccAddress","city":"Perth","state":"WA","country":"AU","postalCode":"6000","fullAddress":"TestAccAddress, Perth WA 6000","id":"h6mdv5aZcKtVnjS0xxxx"},"workflow":{"id":"f77819e0-355b-48c7-a935-c31307bbxxxx","name":"Piepline Movements -> Meta"},"triggerData":{},"customData":{"event_name":"crm_stage_change","stage_name":"New_Leads","meta_id":"invalid_pixel","platform_meta":"true","meta_token":"invalidToken","em":"test@email.com","ph":"","uid":"ItwpBFnGcgcmNzx5xxxx","pipeline_name":"Doomsday_Funnel","fbclid":""},"unit_test_key":"TEST38778","dummy_uri":"https://webhook.site/test-hook"}';

  //const encodedRequestData = JSON.stringify(requestBody);


___NOTES___

Created on 05/05/2025, 12:32:08


