public with sharing class HTTPCalloutResponse {
    public Integer statusCode {
        get { return statusCode; }
        set { statusCode = value; }
    }

    public String status {
        get { return status; }
        set { status = value; }
    }
    public String body {
        get { return body; }
        set { body = value; }
    }

    // Use in Caching algorithm
    public Datetime timeStamp {
        get { return timeStamp; }
        set { timeStamp = value; }
    }

    public HTTPCalloutResponse(Integer statusCode, String status, String body) {
        this.statusCode = statusCode;
        this.status = status;
        this.body = body;
        this.timeStamp = datetime.now();
    }

}