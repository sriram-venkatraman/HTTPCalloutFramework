// Add Description Here
public with sharing class HTTPCalloutService {
    private String serviceLabel;
    private String environmentType;
    private Map<String, String> httpHeaders;
    private String namedCredential;
    private String endPointUrl;
    private String httpMethod;
    private String mockResponseClass;
    private Decimal timeOut;
    private String clientId;
    private String consumerSecret;
    private String refreshToken;
    private String userId;
    private String password;
    private String clientCertificate;
    private String requestBody;
    private List<Integer> validStatusCodes;

    public HTTPCalloutService(String serviceLabel,
                              Map<String, String> dynamicHTTPHeaders,
                              String serviceParameter,
                              String requestBody) {
        List<Integer> s = new List<Integer>();
        s.add(200);
        initObject( serviceLabel,
                    dynamicHTTPHeaders,
                    serviceParameter,
                    requestBody, 
                    s);
    }

    public HTTPCalloutService(String serviceLabel,
                              Map<String, String> dynamicHTTPHeaders,
                              String serviceParameter,
                              String requestBody,
                              List<Integer> validStatusCodes) {
        initObject( serviceLabel,
                    dynamicHTTPHeaders,
                    serviceParameter,
                    requestBody, 
                    validStatusCodes);
    }

    private void initObject(String serviceLabel,
                            Map<String, String> dynamicHTTPHeaders,
                            String serviceParameter,
                            String requestBody,
                            List<Integer> validStatusCodes) {
        this.serviceLabel = serviceLabel;
        String myDomainUrl = System.Url.getOrgDomainUrl().toExternalForm();
        this.environmentType = myDomainUrl.substringAfter('--').substringBefore('.');

        System.debug('Environment: ' + this.environmentType);

        this.validStatusCodes = validStatusCodes.clone();

        List<HTTPCalloutFrameworkConfig__mdt> h = new List<HTTPCalloutFrameworkConfig__mdt>();

        String envLike = '%' + environmentType + ';%';
        String envMockLike = '%mock;%';
        String envDefaultLike = '%default;%';
        try {
            h = [SELECT Client_Certificate_Name__c,
                        Client_Id__c,
                        Consumer_Secret__c,
                        Endpoint_URL__c,
                        HTTP_Method__c,
                        Mock_Response_Class__c,
                        Named_Credentials_Name__c,
                        Refresh_Token__c,
                        Static_Headers__c,
                        Time_Out_in_milliseconds__c,
                        User_Name__c,
                        Password__c
                FROM     HTTPCalloutFrameworkConfig__mdt
                WHERE   MasterLabel = :serviceLabel
                AND     Supported_Environments__c LIKE :envLike];
        }
        catch(Exception ex) {
            throw new HTTPCalloutService.ServiceException('Error! Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + ex.getMessage());
        }
        if (h.size() > 1) {
            throw new HTTPCalloutService.ServiceException('Error! Multiple configurations found for Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType );
        }

        if (h.size() == 1) System.debug('Found a real config');

        if (h.size() == 0) {
            try {
                h = [SELECT Client_Certificate_Name__c,
                            Client_Id__c,
                            Consumer_Secret__c,
                            Endpoint_URL__c,
                            HTTP_Method__c,
                            Mock_Response_Class__c,
                            Named_Credentials_Name__c,
                            Refresh_Token__c,
                            Static_Headers__c,
                            Time_Out_in_milliseconds__c,
                            User_Name__c,
                            Password__c
                    FROM     HTTPCalloutFrameworkConfig__mdt
                    WHERE   MasterLabel = :serviceLabel
                    AND     (Supported_Environments__c LIKE :envMockLike OR
                             Supported_Environments__c LIKE :envDefaultLike) ];
            }
            catch(Exception ex) {
                throw new HTTPCalloutService.ServiceException('Error! Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + ex.getMessage());
            }
            if (h.size() > 1) {
                throw new HTTPCalloutService.ServiceException('Error! Multiple mock/default configurations found for Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType );
            }
            if (h.size() == 0) {
                throw new HTTPCalloutService.ServiceException('Error! No real or mock configuration found for Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType );
            }
            if (h.size() == 1) System.debug('Found a mock config');
        }
        
        System.debug(h);
        namedCredential = h[0].Named_Credentials_Name__c;
        endPointUrl = h[0].Endpoint_URL__c + serviceParameter;

        if (namedCredential != null) {
            endPointUrl = 'callout:' + namedCredential + serviceParameter;
        }

        httpMethod = h[0].HTTP_Method__c;
        mockResponseClass = h[0].Mock_Response_Class__c;
        timeOut = h[0].Time_Out_in_milliseconds__c;
        clientId = h[0].Client_Id__c;
        consumerSecret = h[0].Consumer_Secret__c;
        refreshToken = h[0].Refresh_Token__c;
        userId = h[0].User_Name__c;
        password = h[0].Password__c;
        clientCertificate = h[0].Client_Certificate_Name__c;

        List<String> keyValue;
        httpHeaders = new Map<String,String>();
        if (h[0].Static_Headers__c != null) {
            for (String sh : h[0].Static_Headers__c.split(';')) {
                keyValue = sh.split(':');
                if (keyValue.size() != 2) {
                    throw new HTTPCalloutService.ServiceException('Error! Bad Static Header found in Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + keyValue);
                }
                httpHeaders.put(keyValue[0], keyValue[1]);
            }
        }
        if (dynamicHTTPHeaders != null) {
            httpHeaders.putAll(dynamicHTTPHeaders);
        }
        System.debug('HttpHeaders: ' + httpHeaders);

        this.requestBody = requestBody;
    }

    public HTTPCalloutResponse callOut() {
        if (mockResponseClass != null) {
            Type t = Type.forName(mockResponseClass);
            HTTPCalloutStub v = (HTTPCalloutStub)t.newInstance();
            return v.getResponse();
        }

        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endPointUrl);
            req.setMethod(httpMethod);

            for (String key : httpHeaders.keySet()){
                req.setHeader(key, httpHeaders.get(key));
            }
            req.setBody(requestBody);
            if (timeOut != null) req.setTimeout(timeOut.intValue());

            Http httpClient = new Http();
            HttpResponse rsp = httpClient.send(req);
            
            if (!this.validStatusCodes.contains(rsp.getStatusCode())) {
                throw new HTTPCalloutService.ServiceException('Error! Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + 
                                                                'Status: ' + rsp.getStatusCode() + '-' + rsp.getStatus());
            }

            return (new HTTPCalloutResponse (rsp.getStatusCode(), rsp.getStatus(), rsp.getBody()));
        }
        catch(Exception ex) {
            throw new HTTPCalloutService.ServiceException(ex.getMessage());
        } 
    }

    public class ServiceException extends Exception { }
}