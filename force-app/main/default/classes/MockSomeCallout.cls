public with sharing class MockSomeCallout implements HTTPCalloutStub {
    public MockSomeCallout() {

    }

    public HTTPCalloutResponse getResponse() {
        return (new HTTPCalloutResponse(200, 'OK', '{    "args": {        "parm1": "STUBBED RESPONSE"    },    "data": "Sriram is expected to be sent back as part of response body",    "files": {},    "form": {},    "json": null,    "url": "https://postman-echo.com/post?parm1=Venkatraman"}'));
    }
}
