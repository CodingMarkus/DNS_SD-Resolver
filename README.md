# DNS_SD-Resolver

[`dns_sd`](https://developer.apple.com/documentation/dnssd/dns_service_discovery_c) is the name of the standard DNS service API on Apple's Darwin platform (macOS, iOS, iPadOS, tvOS, ...). It can resolve DNS names using the default DNS servers configured in the system, custom DNS servers provided by API calls, as well as via [multicast DNS](https://en.wikipedia.org/wiki/Multicast_DNS) (mDNS or as Apple calls it "Bonjour"). 

UNIX DNS functions like [`getaddrinfo()`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/getaddrinfo.3.html)/[`gethostbyname()`](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man3/gethostbyname.3.html#//apple_ref/doc/man/3/gethostbyname) or higher-level system APIs like [`CFHost`](https://developer.apple.com/documentation/cfnetwork/cfhost) or [`NSURLConnection`](https://developer.apple.com/documentation/foundation/nsurlconnection/) all use `dns_sd` under the hood for name resolution. For more details on Darwin name DNS name resolution, see Apple's [Resolving DNS Hostnames](https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NetworkingTopics/Articles/ResolvingDNSHostnames.html) guide.

The advantage of using `dns_sd` directly is that the API is fully asynchronous, so it will never block your main thread (and you also don't have to spawn a new thread for each DNS lookup), and it is callable, so you can easily implement your own custom DNS timeout (since the default timeouts are in the range of 30 seconds to 2 minutes, which is an eternity for most users and developers) or allow the request to be canceled when no longer needed (e.g. when the user cancels the connection request).

The downside is that it is a low-level C API, has no automatic memory management, has a clumsy interface, and is not easy to use from Objective-C or Swift. That's why I wrote this wrapper. It takes care of all the memory management and thread safety issues for you, and provides an easy-to-use Obj-C interface that can also be easily used from within your Swift code.

Currently, it only supports resolving DNS names using system-configured DNS resolvers. However, methods for resolving names using custom DNS servers or via mDNS may be added in the future.

## How to use it?

Just copy `src/DNS_SD_Resolver.h` and `src/DNS_SD_Resolver.m` into your project, make sure they are added to the appropriate target and start using them. `DNS_SD_Resolver.h` contains the complete interface, make sure to add it to your Swift bridging header if you want to use the class in Swift code. `DNS_SD_Resolver.m` contains all the wrapper implementation you need. The rest of the files are just for developing and testing the code.
