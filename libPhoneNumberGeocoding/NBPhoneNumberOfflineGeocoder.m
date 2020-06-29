//
//  NBPhoneNumberOfflineGeocoder.m
//  libPhoneNumberiOS
//
//  Created by Rastaar Haghi on 6/12/20.
//  Copyright © 2020 Google LLC. All rights reserved.
//

#import "NBPhoneNumberOfflineGeocoder.h"
#import "Metadata/NBGeocoderMetadataHelper.h"
#import "NBPhoneNumber.h"
#import "NBPhoneNumberUtil.h"

@implementation NBPhoneNumberOfflineGeocoder {
 @private
  NBPhoneNumberUtil *_phoneNumberUtil;
  NSCache<NSString *, NBGeocoderMetadataHelper *> *_metadataHelpers;
  NSNumber const *_US_REGION_CODE;
  NBGeocoderMetadataHelperFactory _metadataHelperFactory;
}

NSString *const _INVALID_REGION_CODE = @"ZZ";

- (instancetype)init {
  return [self initWithMetadataHelperFactory:^NBGeocoderMetadataHelper *(
                   NSNumber *_Nonnull countryCode, NSString *_Nonnull language) {
    return [[NBGeocoderMetadataHelper alloc] initWithCountryCode:countryCode withLanguage:language];
  }];
}

- (instancetype)initWithMetadataHelperFactory:(NBGeocoderMetadataHelperFactory)factory {
  self = [super init];
  if (self != nil) {
    _phoneNumberUtil = NBPhoneNumberUtil.sharedInstance;
    _metadataHelpers = [[NSCache alloc] init];
    _US_REGION_CODE = @1;
    _metadataHelperFactory = [factory copy];
  }
  return self;
}

+ (NBPhoneNumberOfflineGeocoder *)sharedInstance {
  static dispatch_once_t onceToken;
  static NBPhoneNumberOfflineGeocoder *instance;
  dispatch_once(&onceToken, ^{
    instance = [[self alloc] init];
  });
  return instance;
}

- (nullable NSString *)descriptionForValidNumber:(NBPhoneNumber *)phoneNumber
                                withLanguageCode:(NSString *)languageCode {
  // If the NSCache doesn't contain a key equivalent to languageCode, create a new
  // NBGeocoderMetadataHelper object with a language set equal to languageCode and
  // default country code to United States / Canada
  if ([_metadataHelpers objectForKey:languageCode] == nil) {
    [_metadataHelpers setObject:_metadataHelperFactory(phoneNumber.countryCode, languageCode)
                         forKey:languageCode];
  }
  NSString *ans = [[_metadataHelpers objectForKey:languageCode] searchPhoneNumber:phoneNumber];
  if (ans == nil) {
    return [self countryNameForNumber:phoneNumber withLanguageCode:languageCode];
  } else {
    return ans;
  }
}

- (nullable NSString *)descriptionForValidNumber:(NBPhoneNumber *)phoneNumber
                                withLanguageCode:(NSString *)languageCode
                                  withUserRegion:(NSString *)userRegion {
  NSString *regionCode = [_phoneNumberUtil getRegionCodeForNumber:phoneNumber];
  if ([userRegion isEqualToString:regionCode]) {
    return [self descriptionForValidNumber:phoneNumber withLanguageCode:languageCode];
  }
  return [self regionDisplayName:regionCode withLanguageCode:languageCode];
}

- (nullable NSString *)descriptionForNumber:(NBPhoneNumber *)phoneNumber
                           withLanguageCode:(NSString *)languageCode {
  NBEPhoneNumberType numberType = [_phoneNumberUtil getNumberType:phoneNumber];
  if (numberType == NBEPhoneNumberTypeUNKNOWN) {
    return nil;
  } else if (![_phoneNumberUtil isNumberGeographical:phoneNumber]) {
    return [self countryNameForNumber:phoneNumber withLanguageCode:languageCode];
  }
  return [self descriptionForValidNumber:phoneNumber withLanguageCode:languageCode];
}

- (nullable NSString *)descriptionForNumber:(NBPhoneNumber *)phoneNumber
                           withLanguageCode:(NSString *)languageCode
                             withUserRegion:(NSString *)userRegion {
  NBEPhoneNumberType numberType = [_phoneNumberUtil getNumberType:phoneNumber];
  if (numberType == NBEPhoneNumberTypeUNKNOWN) {
    return nil;
  } else if (![_phoneNumberUtil isNumberGeographical:phoneNumber]) {
    return [self countryNameForNumber:phoneNumber withLanguageCode:languageCode];
  }
  return [self descriptionForValidNumber:phoneNumber
                        withLanguageCode:languageCode
                          withUserRegion:userRegion];
}

- (nullable NSString *)descriptionForNumber:(NBPhoneNumber *)phoneNumber {
  NBEPhoneNumberType numberType = [_phoneNumberUtil getNumberType:phoneNumber];
  NSString *languageCode = [[NSLocale preferredLanguages] firstObject];

  if (languageCode == nil) {
    return nil;
  }

  if (numberType == NBEPhoneNumberTypeUNKNOWN) {
    return nil;
  } else if (![_phoneNumberUtil isNumberGeographical:phoneNumber]) {
    return [self countryNameForNumber:phoneNumber withLanguageCode:languageCode];
  }
  return [self descriptionForValidNumber:phoneNumber withLanguageCode:languageCode];
}

- (nullable NSString *)descriptionForNumber:(NBPhoneNumber *)phoneNumber
                             withUserRegion:(NSString *)userRegion {
  NBEPhoneNumberType numberType = [_phoneNumberUtil getNumberType:phoneNumber];
  NSString *languageCode = [[NSLocale preferredLanguages] firstObject];

  if (languageCode == nil) {
    return nil;
  }

  if (numberType == NBEPhoneNumberTypeUNKNOWN) {
    return nil;
  } else if (![_phoneNumberUtil isNumberGeographical:phoneNumber]) {
    return [self countryNameForNumber:phoneNumber withLanguageCode:languageCode];
  }
  return [self descriptionForValidNumber:phoneNumber
                        withLanguageCode:languageCode
                          withUserRegion:userRegion];
}

- (nullable NSString *)countryNameForNumber:(NBPhoneNumber *)number
                           withLanguageCode:(NSString *)languageCode {
  NSArray *regionCodes = [_phoneNumberUtil getRegionCodesForCountryCode:number.countryCode];
  if ([regionCodes count] == 1) {
    return [self regionDisplayName:regionCodes[0] withLanguageCode:languageCode];
  } else {
    NSString *regionWhereNumberIsValid = _INVALID_REGION_CODE;
    for (NSString *regionCode in regionCodes) {
      if ([_phoneNumberUtil isValidNumberForRegion:number regionCode:regionCode]) {
        if (![regionWhereNumberIsValid isEqualToString:_INVALID_REGION_CODE]) {
          return nil;
        }
        regionWhereNumberIsValid = regionCode;
      }
    }

    return [self regionDisplayName:regionWhereNumberIsValid withLanguageCode:languageCode];
  }
}

- (nullable NSString *)regionDisplayName:(NSString *)regionCode
                        withLanguageCode:(NSString *)languageCode {
  if (regionCode == nil || [regionCode isEqualToString:_INVALID_REGION_CODE] ||
      [regionCode isEqual:NB_REGION_CODE_FOR_NON_GEO_ENTITY]) {
    return nil;
  } else {
    return [[NSLocale localeWithLocaleIdentifier:languageCode] displayNameForKey:NSLocaleCountryCode
                                                                           value:regionCode];
  }
}

@end
