[![Deploy to Salesforce](https://andrewfawcett.files.wordpress.com/2014/09/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/sriram-venkatraman/HTTPCalloutFramework)

# HTTP Callout Framework
*Note: Still tidying up with test classes and documentation. Functionality seems to work reasonably well although I haven't done extensive test*

This framework uses a dependency injection pattern to streamline Apex HTTP Callouts across sandbox environments. Framework includes -
* Caching support using platform caching to improve throughput
* Stubbed http responses for sandbox environments that do not need/have real integration endpoints to support.

Dependency injection is done thru' custom metadata type called __HTTPCalloutFrameworkConfig__ and the main service class __HTTPCalloutService__ uses *System.Url.getOrgDomainUrl().toExternalForm()* to intercept the sandbox name and to get the appropriate Config setup from the custom metadata type. Also the service class mandates that __prod__ is isolated from non-prod configuration to ensure no potential overlaps. This way Callouts are made only to appropriate environment specific endpoints with greater isolation for Production endpoints.

This framework supports both static http headers & url parameters via configuration setup. Dynamic headers and parameters are supported through the service class.

* Environment aware callout using a dependency injection pattern that is driven by a environment specific config (custom metadata type)
* Abililty to tag multiple sandboxes to one environment configuration 
* Forced Production configuration isolation.
* Auth dependent on Named Credentials only at this point.
* No Auth endpoint urls are supported via config (*if you dare!!*)
* Caching support for Http Responses. Request parameters & body are MD5 hashed to store responses in Platform Cache. 
* Cache retentions are configurable for each callout & environment. Size of cache depends on what is available to the partition. *Give it a try and procure more if it improves your throughput.*
* Ability to mock http responses using a stubbed class that implements HTTPCalloutStub interface.
* Ability to pass valid http status codes to the callout to ensure expected responses are returned

*To be implemented: Unified callout framework, take away any auth overhead from calling processes* 

## Sample Callout
![Sample Named Credential](/assets/images/HTTPCalloutServiceNCSample.png)
![Sample Configuration with Named Credential](/assets/images/HTTPCalloutServiceCMDTSample.png)
![Sample Configuration with Mock Class](/assets/images/HTTPCalloutServiceCMDTSample2.png)
```
HTTPCalloutService hcs = new HTTPCalloutService('Call POST', 
                                                new Map<String, String>(),
                                                '/post?parm1=Venkatraman',
                                                'This is expected to be sent back as part of response body'
                                            );
System.Debug(hcs.callOut());
```

## Important
* If caching is required, required Platform Cache (Org or Session) should be created and the specified in the Custom Metadata Config
* At this time this framework relies only on Named Credentials to ensure credentials are secured. Future enhancements could include leveraging custom auth mechanisms.

## Dev, Build and Test

## Resources

## Description of Files and Directories

## Issues
