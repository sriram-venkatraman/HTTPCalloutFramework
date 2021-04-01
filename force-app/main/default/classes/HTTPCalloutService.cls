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
  private String orgOrSession;
  private String cachePartition;
  private Cache.OrgPartition orgPart;
  private Cache.SessionPartition sessionPart;
  private Map<String, String> dynamicHTTPHeaders;
  private String serviceParameter;
  private Object mockInput;

  public HTTPCalloutService(
    String serviceLabel,
    Map<String, String> dynamicHTTPHeaders,
    String serviceParameter,
    String requestBody
  ) {
    List<Integer> s = new List<Integer>();
    s.add(200);
    initObject(
      serviceLabel,
      dynamicHTTPHeaders,
      serviceParameter,
      requestBody,
      s,
      null
    );
  }

  public HTTPCalloutService(
    String serviceLabel,
    Map<String, String> dynamicHTTPHeaders,
    String serviceParameter,
    String requestBody,
    List<Integer> validStatusCodes,
    Object mockInput
  ) {
    initObject(
      serviceLabel,
      dynamicHTTPHeaders,
      serviceParameter,
      requestBody,
      validStatusCodes,
      mockInput
    );
  }

  private void initObject(
    String serviceLabel,
    Map<String, String> dynamicHTTPHeaders,
    String serviceParameter,
    String requestBody,
    List<Integer> validStatusCodes,
    Object mockInput
  ) {
    this.serviceLabel = serviceLabel;
    this.dynamicHTTPHeaders = dynamicHTTPHeaders;
    this.serviceParameter = serviceParameter;
    String myDomainUrl = System.Url.getOrgDomainUrl().toExternalForm();

    this.environmentType = HTTPCalloutService.getEnvironmentName();
    System.debug('Environment: ' + this.environmentType);

    this.validStatusCodes = validStatusCodes.clone();

    this.mockInput = mockInput;

    this.getConfig();

    this.requestBody = requestBody;

    if (this.cacheEnabled) {
      if (this.orgOrSession == 'Org')
        this.orgPart = Cache.Org.getPartition(this.cachePartition);
      else
        this.sessionPart = Cache.Session.getPartition(this.cachePartition);
    }
  }

  public HTTPCalloutResponse callOut() {
    if (mockResponseClass != null) {
      Type t = Type.forName(mockResponseClass);
      HTTPCalloutStub v = (HTTPCalloutStub) t.newInstance();
      return v.getResponse(this.mockInput);
    }

    String keyToHash = '';
    try {
      HttpRequest req = new HttpRequest();
      req.setEndpoint(this.endPointUrl);
      req.setMethod(this.httpMethod);

      for (String key : this.httpHeaders.keySet()) {
        req.setHeader(key, this.httpHeaders.get(key));
      }
      req.setBody(requestBody);

      if (this.timeOut != null) {
        req.setTimeout(this.timeOut.intValue());
      }

      // If Cache Enabled, response exists in Cache &  not expired then return the response from Cache.
      Blob targetBlob;
      String hash;
      System.debug(
        'Cache: Enabled: ' +
        this.cacheEnabled +
        '; Period: ' +
        this.cacheRetentionPeriod
      );
      if (this.cacheEnabled && this.cacheRetentionPeriod > 0) {
        // Hash the request to form cache key
        keyToHash = this.endPointUrl + this.httpMethod;
        for (String key : this.httpHeaders.keySet()) {
          keyToHash += key + this.httpHeaders.get(key);
        }
        keyToHash += this.requestBody;

        targetBlob = Blob.valueOf(keyToHash);
        hash = EncodingUtil.convertToHex(
          Crypto.generateDigest('MD5', targetBlob)
        );

        System.Debug(
          'keyToHash Length:' +
          keyToHash.length() +
          ' keyToHash: ' +
          keyToHash
        );
        System.Debug('Hash Length:' + hash.length() + ' hash: ' + hash);

        // If key exists in Org or Session cache then return that.
        if (
          this.orgOrSession == 'Org'
            ? orgPart.contains(hash)
            : sessionPart.contains(hash)
        ) {
          HTTPCalloutResponse cachedResponse = (HTTPCalloutResponse) (orgOrSession ==
            'Org'
            ? orgPart.get(hash)
            : sessionPart.get(hash));
          if (cachedResponse != null) {
            System.Debug('Getting from Cache');
            return cachedResponse;
          }
        }
      }

      // If no cache or expired cache, then go ahead and make the http call
      Http httpClient = new Http();
      HttpResponse rsp = httpClient.send(req);

      if (!this.validStatusCodes.contains(rsp.getStatusCode())) {
        throw new HTTPCalloutService.ServiceException(
          'Error! Service Label: ' +
          this.serviceLabel +
          ' & Environment Type: ' +
          this.environmentType +
          '\n' +
          'Status: ' +
          rsp.getStatusCode() +
          '-' +
          rsp.getStatus()
        );
      }

      HTTPCalloutResponse response = new HTTPCalloutResponse(
        rsp.getStatusCode(),
        rsp.getStatus(),
        rsp.getBody()
      );

      // If Cache Enabled and you got a response without errors then write the response into cache
      if (this.cacheEnabled) {
        if (this.cacheRetentionPeriod > 0) {
          if (this.orgOrSession == 'Org') {
            orgPart.put(hash, response, this.cacheRetentionPeriod);
          } else {
            sessionPart.put(hash, response, this.cacheRetentionPeriod);
          }
        } else {
          if (this.orgOrSession == 'Org') {
            orgPart.put(hash, response);
          } else {
            sessionPart.put(hash, response);
          }
        }
      }
      return (response);
    } catch (Exception ex) {
      throw new HTTPCalloutService.ServiceException(
        ex.getMessage() +
        '\nStack Trace: ' +
        ex.getStackTraceString()
      );
    }
  }

  // Basically get the sandbox / org name
  public static string getEnvironmentName() {
    String myDomainUrl = System.Url.getOrgDomainUrl().toExternalForm();
    if (myDomainUrl.indexOf('--') > 0) {
      return myDomainUrl.substringAfter('--').substringBefore('.');
    } else {
      return 'prod';
    }
  }

  // Get config from CMDT
  public void getConfig() {
    List<HTTPCalloutFrameworkConfig__mdt> h = new List<HTTPCalloutFrameworkConfig__mdt>();
    String configSOQL =
      'SELECT  Client_Certificate_Name__c, ' +
      '        Client_Id__c, ' +
      '        Consumer_Secret__c,' +
      '        Endpoint_URL__c, ' +
      '        HTTP_Method__c, ' +
      '        Mock_Response_Class__c, ' +
      '        Named_Credentials_Name__c, ' +
      '        Refresh_Token__c, ' +
      '        Static_Headers__c, ' +
      '        Time_Out_in_milliseconds__c, ' +
      '        User_Name__c, ' +
      '        Password__c, ' +
      '        Enable_Caching__c, ' +
      '        Cache_Retention_in_Seconds__c, ' +
      '        Org_or_Session_Partition__c, ' +
      '        Platform_Cache_Partition_Name__c ' +
      'FROM    HTTPCalloutFrameworkConfig__mdt ' +
      'WHERE   MasterLabel = :serviceLabel ';

    try {
      /* Production needs to have a separate unique configuration and can't be combined with
       ** sandbox configuration to ensure there is clear distinction.
       */
      if (this.environmentType == 'prod') {
        h = Database.query(
          configSOQL +
          'AND Supported_Environments__c = \'' +
          this.environmentType +
          '\''
        );
      } else {
        // If environment is sandbox then get the config with sandbox name in it
        h = Database.query(
          configSOQL +
          'AND     (Supported_Environments__c LIKE \'%,' +
          this.environmentType +
          ',%\' OR ' +
          '         Supported_Environments__c LIKE \'' +
          this.environmentType +
          ',%\' OR ' +
          '         Supported_Environments__c LIKE \'%,' +
          this.environmentType +
          '\' OR ' +
          '         Supported_Environments__c LIKE \'' +
          this.environmentType +
          '\')'
        );
      }
    } catch (Exception ex) {
      throw new HTTPCalloutService.ServiceException(
        'Error! Service Label: ' +
        this.serviceLabel +
        ' & Environment Type: ' +
        this.environmentType +
        '\n' +
        ex.getMessage()
      );
    }
    if (h.size() > 1) {
      throw new HTTPCalloutService.ServiceException(
        'Error! Multiple configurations found for Service Label: ' +
        this.serviceLabel +
        ' & Environment Type: ' +
        this.environmentType
      );
    }

    if (h.size() == 1) {
      System.debug('Found a real config');
    }

    if (h.size() == 0) {
      // If no config found and this is prod environement then throw error
      if (this.environmentType == 'prod') {
        throw new HTTPCalloutService.ServiceException(
          'Error! No configuration found for Service Label: ' +
          this.serviceLabel +
          ' & Environment Type: ' +
          this.environmentType
        );
      }

      // If no config found and this is not prod, then try to find if there is a mock/default config
      try {
        h = Database.query(
          configSOQL +
          'AND     (Supported_Environments__c LIKE \'%,mock,%\' OR ' +
          '         Supported_Environments__c LIKE \'mock,%\' OR ' +
          '         Supported_Environments__c LIKE \'%,mock\' OR ' +
          '         Supported_Environments__c LIKE \'mock\' OR ' +
          '         Supported_Environments__c LIKE \'%,default,%\' OR ' +
          '         Supported_Environments__c LIKE \'default,%\' OR ' +
          '         Supported_Environments__c LIKE \'%,default\' OR ' +
          '         Supported_Environments__c LIKE \'default\')'
        );
      } catch (Exception ex) {
        throw new HTTPCalloutService.ServiceException(
          'Error! Service Label: ' +
          this.serviceLabel +
          ' & Environment Type: ' +
          this.environmentType +
          '\n' +
          ex.getMessage()
        );
      }
      if (h.size() > 1) {
        throw new HTTPCalloutService.ServiceException(
          'Error! Multiple mock/default configurations found for Service Label: ' +
          this.serviceLabel +
          ' & Environment Type: ' +
          this.environmentType
        );
      }
      if (h.size() == 0) {
        throw new HTTPCalloutService.ServiceException(
          'Error! No real or mock configuration found for Service Label: ' +
          this.serviceLabel +
          ' & Environment Type: ' +
          this.environmentType
        );
      }
      if (h.size() == 1)
        System.debug('Found a mock config');
    }

    System.debug(h);
    // If you have come this far without exceptions, then you got a good config to work with
    // Set all the properties.
    this.namedCredential = h[0].Named_Credentials_Name__c;
    this.endPointUrl = h[0].Endpoint_URL__c + this.serviceParameter;

    if (this.namedCredential != null) {
      this.endPointUrl = 'callout:' + namedCredential + this.serviceParameter;
    }

    this.httpMethod = h[0].HTTP_Method__c;
    this.mockResponseClass = h[0].Mock_Response_Class__c;
    this.timeOut = h[0].Time_Out_in_milliseconds__c;

    // Caching stuff
    this.cacheEnabled = h[0].Enable_Caching__c;
    this.cacheRetentionPeriod = (h[0].Cache_Retention_in_Seconds__c == null
      ? 0
      : h[0].Cache_Retention_in_Seconds__c.intValue());
    this.orgOrSession = h[0].Org_or_Session_Partition__c;
    this.cachePartition = h[0].Platform_Cache_Partition_Name__c;

    // Custom http headers
    List<String> keyValue;
    this.httpHeaders = new Map<String, String>();
    if (h[0].Static_Headers__c != null) {
      for (String sh : h[0].Static_Headers__c.split('\n')) {
        keyValue = sh.split(':');
        if (keyValue.size() != 2) {
          throw new HTTPCalloutService.ServiceException(
            'Error! Bad Static Header found in Service Label: ' +
            this.serviceLabel +
            ' & Environment Type: ' +
            this.environmentType +
            '\n' +
            keyValue
          );
        }
        this.httpHeaders.put(keyValue[0], keyValue[1]);
      }
    }
    if (dynamicHTTPHeaders != null) {
      this.httpHeaders.putAll(this.dynamicHTTPHeaders);
    }
    System.debug('HttpHeaders: ' + this.httpHeaders);

    // Custom authentications are not supported now. This framework relys on the awesome Named Credentials to
    // handle all that. So the following parameters are redundant. Could be supported in future if needed.
    this.clientId = h[0].Client_Id__c;
    this.consumerSecret = h[0].Consumer_Secret__c;
    this.refreshToken = h[0].Refresh_Token__c;
    this.userId = h[0].User_Name__c;
    this.password = h[0].Password__c;
    this.clientCertificate = h[0].Client_Certificate_Name__c;
  }

  public class ServiceException extends Exception {
  }
}
