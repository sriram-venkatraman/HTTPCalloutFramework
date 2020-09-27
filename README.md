# HTTP Callout Framework
*Note: Still tyding up with test classes and documentation. Functionality seems to work reasonably well although I haven't done extensive test*

This framework uses a dependency injection pattern to streamline Apex HTTP Callouts across sandbox environments. Fremework includes -
* Caching support using platform caching to improve throughput
* Stubbed http responses for sandbox environments that do not need/have real integration endpoints to support.

Dependency injection is done thru' custom metadata type called __HTTPCalloutFrameworkConfig__ and the main service class __HTTPCalloutService__ uses *System.Url.getOrgDomainUrl().toExternalForm()* to intercept the sandbox name and to get the appropriate Config setup from the custom metadata type. Also the service class mandates that __prod__ is isolated from non-prod configuration to ensure no potential overlaps. This way Callouts are made only to appropriate environment specific endpoints with greater isolation for Production endpoints.

This framework supports both static http headers & url parameters via configuration setup. Dynamic headers and parameters are supported through the service class.

## Important
* If caching is required, required Platform Cache (Org or Session) should be created and the specified in the Custom Metadata Config
* At this time this framework relies only on Named Credentials to ensure credentials are secured. Future enhancements could include leveraging custom auth mechanisms.

## Dev, Build and Test
[![Deploy to Salesforce](https://andrewfawcett.files.wordpress.com/2014/09/deploy.png)](https://githubsfdeploy.herokuapp.com/app/githubdeploy/sriram-venkatraman/HTTPCalloutFramework)

## Resources

## Description of Files and Directories

## Issues
