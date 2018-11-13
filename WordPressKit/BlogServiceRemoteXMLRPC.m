#import "BlogServiceRemoteXMLRPC.h"
#import "NSMutableDictionary+Helpers.h"
#import "RemotePostType.h"
#import "WPKitLoggingPrivate.h"
#import <WordPressKit/WordPressKit-Swift.h>
@import NSObject_SafeExpectations;
@import WordPressShared;

static NSString * const RemotePostTypeNameKey = @"name";
static NSString * const RemotePostTypeLabelKey = @"label";
static NSString * const RemotePostTypePublicKey = @"public";

@implementation BlogServiceRemoteXMLRPC

- (void)getAuthorsWithSuccess:(UsersHandler)success
                      failure:(void (^)(NSError *))failure
{
    NSDictionary *filter = @{@"who":@"authors"};
    NSArray *parameters = [self XMLRPCArgumentsWithExtra:filter];
    [self.api callMethod:@"wp.getUsers"
              parameters:parameters
                 success:^(id responseObject, NSHTTPURLResponse *response) {
                     NSArray <RemoteUser *> *users = [[responseObject allObjects] wp_map:^id(NSDictionary *xmlrpcUser) {
                         return [self remoteUserFromXMLRPCDictionary:xmlrpcUser];
                     }];
                     if (success) {
                         success(users);
                     }
                     
                 } failure:^(NSError *error, NSHTTPURLResponse *response) {
                     if (failure) {
                         failure(error);
                     }
                 }];
}

- (void)getAllAuthorsWithNumber:(NSNumber *)number
                        success:(UsersHandler)success
                        failure:(void (^)(NSError *error))failure
{
    NSMutableArray *remoteUsers = [NSMutableArray array];
    [self getAllAuthorsWithRemoteUsers:remoteUsers
                                number:number
                                offset:nil
                               success:success
                               failure:failure];
}

- (void)getAllAuthorsWithRemoteUsers:(NSMutableArray <RemoteUser *>*)remoteusers
                              number:(NSNumber *)number
                              offset:(NSNumber *)offset
                             success:(UsersHandler)success
                             failure:(void (^)(NSError *error))failure
{
    NSMutableDictionary *filter = [@{ @"who":@"authors" } mutableCopy];
    
    if (offset != nil) {
        filter[@"offset"] = offset.stringValue;
    }
    
    if (number != nil) {
        filter[@"number"] = number.stringValue;
    }
    
    NSArray *parameters = [self XMLRPCArgumentsWithExtra:filter];
    [self.api callMethod:@"wp.getUsers"
              parameters:parameters
                 success:^(id responseObject, NSHTTPURLResponse *response) {
                     NSArray <RemoteUser *> *users = [[responseObject allObjects] wp_map:^id(NSDictionary *xmlrpcUser) {
                         return [self remoteUserFromXMLRPCDictionary:xmlrpcUser];
                     }];
                     if (success) {
                         if (users == nil || users.count == 0) {
                             success(remoteusers);
                         } else {
                             [remoteusers addObjectsFromArray:users];
                             [self getAllAuthorsWithRemoteUsers:remoteusers
                                                         number:number
                                                         offset:@(remoteusers.count)
                                                        success:success
                                                        failure:failure];
                         }
                     }
                     
                 } failure:^(NSError *error, NSHTTPURLResponse *response) {
                     if (failure) {
                         failure(error);
                     }
                 }];
}

- (void)syncPostTypesWithSuccess:(PostTypesHandler)success failure:(void (^)(NSError *error))failure
{
    NSArray *parameters = [self defaultXMLRPCArguments];
    [self.api callMethod:@"wp.getPostTypes"
              parameters:parameters
                 success:^(id responseObject, NSHTTPURLResponse *response) {

                     NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Response should be a dictionary.");
                     NSArray <RemotePostType *> *postTypes = [[responseObject allObjects] wp_map:^id(NSDictionary *json) {
                         return [self remotePostTypeFromXMLRPCDictionary:json];
                     }];
                     if (!postTypes.count) {
                         DDLogError(@"Response to wp.getPostTypes did not include post types for site.");
                         failure(nil);
                         return;
                     }
                     if (success) {
                         success(postTypes);
                     }
                 } failure:^(NSError *error, NSHTTPURLResponse *response) {
                     DDLogError(@"Error syncing post types (%@): %@", response.URL, error);
                     
                     if (failure) {
                         failure(error);
                     }
                 }];
}

- (void)syncPostFormatsWithSuccess:(PostFormatsHandler)success failure:(void (^)(NSError *))failure
{
    NSDictionary *dict = @{@"show-supported": @"1"};
    NSArray *parameters = [self XMLRPCArgumentsWithExtra:dict];

    [self.api callMethod:@"wp.getPostFormats"
              parameters:parameters
                 success:^(id responseObject, NSHTTPURLResponse *response) {
                     NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Response should be a dictionary.");

                     NSDictionary *postFormats = responseObject;
                     NSDictionary *respDict = responseObject;
                     if ([postFormats objectForKey:@"supported"]) {
                         NSMutableArray *supportedKeys;
                         if ([[postFormats objectForKey:@"supported"] isKindOfClass:[NSArray class]]) {
                             supportedKeys = [NSMutableArray arrayWithArray:[postFormats objectForKey:@"supported"]];
                         } else if ([[postFormats objectForKey:@"supported"] isKindOfClass:[NSDictionary class]]) {
                             supportedKeys = [NSMutableArray arrayWithArray:[[postFormats objectForKey:@"supported"] allValues]];
                         }

                         // Standard isn't included in the list of supported formats? Maybe it will be one day?
                         if (![supportedKeys containsObject:@"standard"]) {
                             [supportedKeys addObject:@"standard"];
                         }

                         NSDictionary *allFormats = [postFormats objectForKey:@"all"];
                         NSMutableArray *supportedValues = [NSMutableArray array];
                         for (NSString *key in supportedKeys) {
                             [supportedValues addObject:[allFormats objectForKey:key]];
                         }
                         respDict = [NSDictionary dictionaryWithObjects:supportedValues forKeys:supportedKeys];
                     }
                     
                     if (success) {
                         success(respDict);
                     }
                 } failure:^(NSError *error, NSHTTPURLResponse *response) {
                     DDLogError(@"Error syncing post formats (%@): %@", response.URL, error);
                     
                     if (failure) {
                         failure(error);
                     }
                 }];

}

- (void)syncBlogOptionsWithSuccess:(OptionsHandler)success failure:(void (^)(NSError *))failure
{
    NSArray *parameters = [self defaultXMLRPCArguments];
    [self.api callMethod:@"wp.getOptions"
              parameters:parameters
                 success:^(id responseObject, NSHTTPURLResponse *response) {
                     NSAssert([responseObject isKindOfClass:[NSDictionary class]], @"Response should be a dictionary.");

                     if (success) {
                         success(responseObject);
                     }
                 } failure:^(NSError *error, NSHTTPURLResponse *response) {
                     DDLogError(@"Error syncing blog options: %@", error);

                     if (failure) {
                         failure(error);
                     }
                 }];
}

- (void)updateBlogOptionsWith:(NSDictionary *)remoteBlogOptions success:(SuccessHandler)success failure:(void (^)(NSError *))failure
{
    NSArray *parameters = [self XMLRPCArgumentsWithExtra:remoteBlogOptions];
    [self.api callMethod:@"wp.setOptions" parameters:parameters success:^(id responseObject, NSHTTPURLResponse *response) {
        if (![responseObject isKindOfClass:[NSDictionary class]]) {
            if (failure) {
                failure(nil);
            }
            return;
        }
        if (success) {
            success();
        }
    } failure:^(NSError *error, NSHTTPURLResponse *response) {
        DDLogError(@"Error updating blog options: %@", error);
        if (failure) {
            failure(error);
        }
    }];
}

- (RemoteUser *)remoteUserFromXMLRPCDictionary:(NSDictionary *)xmlrpcUser
{
    RemoteUser *user = [RemoteUser new];
    user.userID = [xmlrpcUser numberForKey:@"user_id"];
    user.username = [xmlrpcUser stringForKey:@"username"];
    user.displayName = [xmlrpcUser stringForKey:@"display_name"];
    return user;
}

- (RemotePostType *)remotePostTypeFromXMLRPCDictionary:(NSDictionary *)json
{
    RemotePostType *postType = [[RemotePostType alloc] init];
    postType.name = [json stringForKey:RemotePostTypeNameKey];
    postType.label = [json stringForKey:RemotePostTypeLabelKey];
    postType.apiQueryable = [json numberForKey:RemotePostTypePublicKey];
    return postType;
}

@end
