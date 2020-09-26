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
    private Boolean cacheEnabled;
    private Integer cacheRetentionPeriod;

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
        if (myDomainUrl.indexOf('--') > 0) {
            this.environmentType = myDomainUrl.substringAfter('--').substringBefore('.');
        }
        else {
            this.environmentType = 'prod';
        }

        System.debug('Environment: ' + this.environmentType);

        this.validStatusCodes = validStatusCodes.clone();

        List<HTTPCalloutFrameworkConfig__mdt> h = new List<HTTPCalloutFrameworkConfig__mdt>();

        try {
            /* Production needs to have a separate unique configuration and can't be combined with
            ** sandbox configuration to ensure there is clear distinction.
            */
            if (this.environmentType == 'prod') {
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
                            Password__c,
                            Enable_Caching__c,
                            Cache_Retention_in_Seconds__c
                    FROM     HTTPCalloutFrameworkConfig__mdt
                    WHERE   MasterLabel = :serviceLabel
                    AND     Supported_Environments__c = 'prod'];
            }
            else {
                String envLike1 = '%,' + this.environmentType + ',%';
                String envLike2 = this.environmentType + ',%';
                String envLike3 = '%,' + this.environmentType;
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
                            Password__c,
                            Enable_Caching__c,
                            Cache_Retention_in_Seconds__c
                    FROM     HTTPCalloutFrameworkConfig__mdt
                    WHERE   MasterLabel = :serviceLabel
                    AND     (Supported_Environments__c LIKE :envLike1 OR 
                             Supported_Environments__c LIKE :envLike2 OR
                             Supported_Environments__c LIKE :envLike3 OR
                             Supported_Environments__c LIKE :this.environmentType)];                
            }
        }
        catch(Exception ex) {
            throw new HTTPCalloutService.ServiceException('Error! Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + ex.getMessage());
        }
        if (h.size() > 1) {
            throw new HTTPCalloutService.ServiceException('Error! Multiple configurations found for Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType );
        }

        if (h.size() == 1) System.debug('Found a real config');

        if (h.size() == 0) {
            if (this.environmentType == 'prod') {
                throw new HTTPCalloutService.ServiceException('Error! No configuration found for Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType );
            }

            String envMockLike1 = '%,mock,%';
            String envMockLike2 = 'mock,%';
            String envMockLike3 = '%,mock';
            String envDefaultLike1 = '%,default,%';
            String envDefaultLike2 = 'default,%';
            String envDefaultLike3 = '%,default';

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
                            Password__c,
                            Enable_Caching__c,
                            Cache_Retention_in_Seconds__c
                    FROM     HTTPCalloutFrameworkConfig__mdt
                    WHERE   MasterLabel = :serviceLabel
                    AND     (Supported_Environments__c LIKE :envMockLike1 OR 
                            Supported_Environments__c LIKE :envMockLike2 OR 
                            Supported_Environments__c LIKE :envMockLike3 OR 
                            Supported_Environments__c LIKE 'mock' OR 
                            Supported_Environments__c LIKE 'default' OR 
                            Supported_Environments__c LIKE :envDefaultLike1 OR
                            Supported_Environments__c LIKE :envDefaultLike2 OR
                            Supported_Environments__c LIKE :envDefaultLike3)];
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
        this.namedCredential = h[0].Named_Credentials_Name__c;
        this.endPointUrl = h[0].Endpoint_URL__c + serviceParameter;

        if (namedCredential != null) {
            this.endPointUrl = 'callout:' + namedCredential + serviceParameter;
        }

        this.httpMethod = h[0].HTTP_Method__c;
        this.mockResponseClass = h[0].Mock_Response_Class__c;
        this.timeOut = h[0].Time_Out_in_milliseconds__c;
        this.clientId = h[0].Client_Id__c;
        this.consumerSecret = h[0].Consumer_Secret__c;
        this.refreshToken = h[0].Refresh_Token__c;
        this.userId = h[0].User_Name__c;
        this.password = h[0].Password__c;
        this.clientCertificate = h[0].Client_Certificate_Name__c;
        this.cacheEnabled = h[0].Enable_Caching__c;
        this.cacheRetentionPeriod = h[0].Cache_Retention_in_Seconds__c.intValue();

        List<String> keyValue;
        this.httpHeaders = new Map<String,String>();
        if (h[0].Static_Headers__c != null) {
            for (String sh : h[0].Static_Headers__c.split('\n')) {
                keyValue = sh.split(':');
                if (keyValue.size() != 2) {
                    throw new HTTPCalloutService.ServiceException('Error! Bad Static Header found in Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + keyValue);
                }
                this.httpHeaders.put(keyValue[0], keyValue[1]);
            }
        }
        if (dynamicHTTPHeaders != null) {
            this.httpHeaders.putAll(dynamicHTTPHeaders);
        }
        System.debug('HttpHeaders: ' + this.httpHeaders);

        this.requestBody = requestBody;
    }

    public HTTPCalloutResponse callOut() {
        if (mockResponseClass != null) {
            Type t = Type.forName(mockResponseClass);
            HTTPCalloutStub v = (HTTPCalloutStub)t.newInstance();
            return v.getResponse();
        }

        String keyToHash = '';
        try {
            HttpRequest req = new HttpRequest();
            req.setEndpoint(endPointUrl);
            if (cacheEnabled && cacheRetentionPeriod > 0) keyToHash += endPointUrl;
            req.setMethod(httpMethod);
            if (cacheEnabled && cacheRetentionPeriod > 0) keyToHash += httpMethod;

            for (String key : httpHeaders.keySet()){
                req.setHeader(key, httpHeaders.get(key));
                if (cacheEnabled && cacheRetentionPeriod > 0) keyToHash += key+httpHeaders.get(key);
            }
            req.setBody(requestBody);
            if (cacheEnabled && cacheRetentionPeriod > 0) keyToHash += requestBody;

            if (timeOut != null) req.setTimeout(timeOut.intValue());

            Cache.OrgPartition orgPart = Cache.Org.getPartition('local.HTTPCalloutCache1');
            Blob targetBlob;
            String hash;
            if (cacheEnabled && cacheRetentionPeriod > 0) {
                targetBlob = Blob.valueOf(keyToHash);
                hash = EncodingUtil.convertToHex(Crypto.generateDigest('MD5', targetBlob));
                System.Debug('keyToHash Length:' + keyToHash.length() + ' keyToHash: ' + keyToHash);
                System.Debug('Hash Length:' + hash.length() + ' hash: ' + hash);
                if (orgPart.contains(hash)) {
                    HTTPCalloutResponse cachedResponse = (HTTPCalloutResponse) orgPart.get(hash);
                    if (cachedResponse != null) {
                        System.Debug('Getting from Cache');
                        return cachedResponse;
                    }
                }
            }

            Http httpClient = new Http();
            HttpResponse rsp = httpClient.send(req);
            
            if (!this.validStatusCodes.contains(rsp.getStatusCode())) {
                throw new HTTPCalloutService.ServiceException('Error! Service Label: ' + serviceLabel + ' & Environment Type: ' + environmentType + '\n' + 
                                                                'Status: ' + rsp.getStatusCode() + '-' + rsp.getStatus());
            }

            HTTPCalloutResponse response = new HTTPCalloutResponse (rsp.getStatusCode(), rsp.getStatus(), rsp.getBody());

            if (cacheEnabled && cacheRetentionPeriod > 0) {
                orgPart.put(hash, response, cacheRetentionPeriod);
            }
            return (response);
        }
        catch(Exception ex) {
            throw new HTTPCalloutService.ServiceException(ex.getMessage() + '\nStack Trace: ' + ex.getStackTraceString());
        } 
    }

    public class ServiceException extends Exception { }
}