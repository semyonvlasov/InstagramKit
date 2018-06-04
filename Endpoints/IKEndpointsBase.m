//
//  IKEndpointsBase.m
//  InstagramKit
//
//  Created by Shyam Bhat on 6/4/18.
//

#import "IKEndpointsBase.h"
#import "AFNetworking.h"
#import "IKConstants.h"

@interface IKEndpointsBase()

@property (nonatomic, copy, nonnull) NSString *appClientID;
@property (nonatomic, copy, nonnull) NSString *appRedirectURL;
@property (nonatomic, strong, nonnull) AFHTTPSessionManager *httpManager;

@end

@implementation IKEndpointsBase

- (instancetype)init {
    
    if (self = [super init])
    {
        NSURL *baseURL = [NSURL URLWithString:kInstagramKitBaseURL];
        self.httpManager = [[AFHTTPSessionManager alloc] initWithBaseURL:baseURL];
        self.httpManager.responseSerializer = [[AFJSONResponseSerializer alloc] init];
        
        NSDictionary *info = [[NSBundle mainBundle] infoDictionary];
        if (INSTAGRAMKIT_TEST_TARGET) {
            info = [[NSBundle bundleForClass:[self class]] infoDictionary];
        }
        
        self.appClientID = info[kInstagramAppClientIdConfigurationKey];
        self.appRedirectURL = info[kInstagramAppRedirectURLConfigurationKey];
        
        if (!self.appClientID || [self.appClientID isEqualToString:@""]) {
            NSLog(@"[InstagramKit] ERROR : Invalid Client ID. Please set a valid value for the key \"%@\" in the App's Info.plist file",kInstagramAppClientIdConfigurationKey);
        }
        
        if (!self.appRedirectURL || [self.appRedirectURL isEqualToString:@""]) {
            NSLog(@"[InstagramKit] ERROR : Invalid Redirect URL. Please set a valid value for the key \"%@\" in the App's Info.plist file",kInstagramAppRedirectURLConfigurationKey);
        }
        
    }
    return self;
}


#pragma mark - Base Calls -


- (void)getPath:(NSString *)path
  responseModel:(Class)modelClass
        success:(InstagramObjectBlock)success
        failure:(InstagramFailureBlock)failure
{
    NSString *percentageEscapedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    [self.httpManager GET:percentageEscapedPath
               parameters:[self dictionaryWithAccessTokenAndParams:nil]
                 progress:nil
                  success:^(NSURLSessionDataTask *task, id responseObject) {
                      if (!success) return;
                      NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                      NSDictionary *dataDictionary = IKNotNull(responseDictionary[kData]) ? responseDictionary[kData] : nil;
                      id modelObject =  (modelClass == [NSDictionary class]) ? [dataDictionary copy] : [[modelClass alloc] initWithInfo:dataDictionary];
                      success(modelObject);
                  }
                  failure:^(NSURLSessionDataTask *task, NSError *error) {
                      (failure) ? failure(error,((NSHTTPURLResponse*)[task response]).statusCode, [self serializedResponseDataFromError:error]) : 0;
                  }];
}


- (void)getPaginatedPath:(NSString *)path
              parameters:(NSDictionary *)parameters
           responseModel:(Class)modelClass
                 success:(InstagramPaginatiedResponseBlock)success
                 failure:(InstagramFailureBlock)failure
{
    NSDictionary *params = [self dictionaryWithAccessTokenAndParams:parameters];
    NSString *percentageEscapedPath = [path stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
    [self.httpManager GET:percentageEscapedPath
               parameters:params
                 progress:nil
                  success:^(NSURLSessionDataTask *task, id responseObject) {
                      if (!success) return;
                      NSDictionary *responseDictionary = (NSDictionary *)responseObject;
                      
                      NSDictionary *pInfo = responseDictionary[kPagination];
                      InstagramPaginationInfo *paginationInfo = IKNotNull(pInfo)?[[InstagramPaginationInfo alloc] initWithInfo:pInfo andObjectType:modelClass]: nil;
                      
                      NSArray *responseObjects = IKNotNull(responseDictionary[kData]) ? responseDictionary[kData] : nil;
                      NSMutableArray *objects = [NSMutableArray arrayWithCapacity:responseObjects.count];
                      dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                          [responseObjects enumerateObjectsUsingBlock:^(NSDictionary * dataDictionary, NSUInteger idx, BOOL *stop) {
                              id modelObject = [[modelClass alloc] initWithInfo:dataDictionary];
                              [objects addObject:modelObject];
                          }];
                          dispatch_async(dispatch_get_main_queue(), ^{
                              success([objects copy], paginationInfo);
                          });
                      });
                  }
                  failure:^(NSURLSessionDataTask *task, NSError *error) {
                      (failure) ? failure(error,((NSHTTPURLResponse*)[task response]).statusCode, [self serializedResponseDataFromError:error]) : 0;
                  }];
}

- (void)postPath:(NSString *)path
      parameters:(NSDictionary *)parameters
         success:(InstagramResponseBlock)success
         failure:(InstagramFailureBlock)failure
{
    [self.httpManager POST:path
                parameters:[self dictionaryWithAccessTokenAndParams:parameters]
                  progress:nil
                   success:^(NSURLSessionDataTask *task, id responseObject) {
                       (success)? success((NSDictionary *)responseObject) : 0;
                   }
                   failure:^(NSURLSessionDataTask *task, NSError *error) {
                       (failure) ? failure(error,((NSHTTPURLResponse*)[task response]).statusCode, [self serializedResponseDataFromError:error]) : 0;
                   }];
}


- (void)deletePath:(NSString *)path
           success:(InstagramResponseBlock)success
           failure:(InstagramFailureBlock)failure
{
    [self.httpManager DELETE:path
                  parameters:[self dictionaryWithAccessTokenAndParams:nil]
                     success:^(NSURLSessionDataTask *task, id responseObject) {
                         (success)? success((NSDictionary *)responseObject) : 0;
                     }
                     failure:^(NSURLSessionDataTask *task, NSError *error) {
                         (failure) ? failure(error,((NSHTTPURLResponse*)[task response]).statusCode, [self serializedResponseDataFromError:error]) : 0;
                     }];
}


- (NSDictionary *)serializedResponseDataFromError:(NSError *)error
{
    NSData *errorData = error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey];
    return [NSJSONSerialization JSONObjectWithData: errorData options:kNilOptions error:nil];
}


#pragma mark - Pagination -


- (void)getPaginatedItemsForInfo:(InstagramPaginationInfo *)paginationInfo
                     withSuccess:(InstagramPaginatiedResponseBlock)success
                         failure:(InstagramFailureBlock)failure
{
    NSString *relativePath = [[paginationInfo.nextURL absoluteString] stringByReplacingOccurrencesOfString:[self.httpManager.baseURL absoluteString] withString:@""];
    relativePath = [relativePath stringByRemovingPercentEncoding];
    [self getPaginatedPath:relativePath
                parameters:nil
             responseModel:paginationInfo.type
                   success:success
                   failure:failure];
}


#pragma mark - Query


- (NSDictionary *)dictionaryWithAccessTokenAndParams:(NSDictionary *)params
{
    NSMutableDictionary *mutableDictionary = [NSMutableDictionary dictionaryWithDictionary:params];
    if (self.accessToken) {
        [mutableDictionary setObject:self.accessToken forKey:kKeyAccessToken];
    }
    else
    {
        [mutableDictionary setObject:self.appClientID forKey:kKeyClientID];
    }
    return [NSDictionary dictionaryWithDictionary:mutableDictionary];
}


- (NSDictionary *)parametersFromCount:(NSInteger)count maxId:(NSString *)maxId andPaginationKey:(NSString *)key
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    if (count) {
        [params setObject:[NSString stringWithFormat:@"%ld",(long)count] forKey:kCount];
    }
    if (maxId) {
        [params setObject:maxId forKey:key];
    }
    return [params copy];
}


@end
