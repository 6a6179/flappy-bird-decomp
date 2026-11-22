# Matching upstream sources

The two Objective-C classes in this directory compile to all 50 of their original methods in each architecture. The manifests pass the SDK’s historical class names to the compiler as preprocessor definitions.

- Google Toolbox for Mac supplies GTMStringEncoding and GTMDefines. The only change to the implementation is a line directive that restores the original filename and line numbers in runtime assertion messages. The Apache license is included. [Upstream revision](https://github.com/google/google-toolbox-for-mac/tree/c3bb90929634ece1a080221dabdf7af6ebbde47d/Foundation)
- SBJSON uses Stig Brautaset’s single-class parser and writer, with the BSD license retained in both source files. The recovered version checks the optional error destination, handles objects that implement stringValue or description, and refers to the two static scanner tables through their shared storage. Line directives restore the assertion metadata. [Upstream revision](https://github.com/stig/json-framework/tree/9ac1698570cc8d83a4f66020f9e830c7693b1e46/Source)

The verifier uses the original SDK headers and Apple clang-500.2.76 for these methods. Both architecture manifests use ARM mode and the iOS 4 deployment target for these two library translation units.
