//
//  AvroKeyboard
//
//  Created by Rifat Nabi on 6/22/12.
//  Copyright (c) 2012 OmicronLab. All rights reserved.
//

#import "RegexParser.h"

static RegexParser* sharedInstance = nil;

@implementation RegexParser

+ (RegexParser *)sharedInstance  {
    if (sharedInstance == nil) {
        [[self alloc] init]; // assignment not done here, see allocWithZone
    }
	return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone {
    
    if (sharedInstance == nil) {
        sharedInstance = [super allocWithZone:zone];
        return sharedInstance;  // assignment and return on first allocation
    }
    return nil; //on subsequent allocation attempts return nil
}

- (id)copyWithZone:(NSZone *)zone {
    return self;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSError *error = nil;
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"regex" ofType:@"json"];
        NSData *jsonData = [NSData dataWithContentsOfFile:filePath options:NSDataReadingUncached error: &error];
        
        if (jsonData) {
            
            NSDictionary *jsonArray = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error: &error];
            
            if (!jsonArray) {
                @throw error;
            } else {
                _vowel = [[NSString alloc] initWithString:jsonArray[@"vowel"]];
                _consonant = [[NSString alloc] initWithString:jsonArray[@"consonant"]];
                _casesensitive = [[NSString alloc] initWithString:jsonArray[@"casesensitive"]];
                _patterns = [[NSArray alloc] initWithArray:jsonArray[@"patterns"]];
                _maxPatternLength = [_patterns[0][@"find"] length];
            }
            
        } else {
            @throw error;
        }
    }
    return self;
}


- (NSString*)parse:(NSString *)string {
    if (!string || string.length == 0) {
        return string;
    }
    
    NSString* fixed = [self clean:string];
    NSMutableString* output = [[NSMutableString alloc] initWithCapacity:0];
    
    NSInteger len = fixed.length, cur;
    for(cur = 0; cur < len; ++cur) {
        NSInteger start = cur, end;
        BOOL matched = FALSE;
        
        NSInteger chunkLen;
        for(chunkLen = _maxPatternLength; chunkLen > 0; --chunkLen) {
            end = start + chunkLen;
            if(end <= len) {
                NSString* chunk = [fixed substringWithRange:NSMakeRange(start, chunkLen)];
                
                // Binary Search
                NSInteger left = 0, right = _patterns.count - 1, mid;
                while(right >= left) {
                    mid = (right + left) / 2;
                    NSDictionary* pattern = _patterns[mid];
                    NSString* find = pattern[@"find"];
                    if([find isEqualToString:chunk]) {
                        NSArray* rules = pattern[@"rules"];
                        for(NSDictionary* rule in rules) {
                            
                            BOOL replace = TRUE;
                            NSInteger chk = 0;
                            NSArray* matches = rule[@"matches"];
                            for(NSDictionary* match in matches) {
                                NSString* value = match[@"value"];
                                NSString* type = match[@"type"];
                                NSString* scope = match[@"scope"];
                                BOOL isNegative = [match[@"negative"] boolValue];
                                
                                if([type isEqualToString:@"suffix"]) {
                                    chk = end;
                                } 
                                // Prefix
                                else {
                                    chk = start - 1;
                                }
                                
                                // Beginning
                                if([scope isEqualToString:@"punctuation"]) {
                                    if(
                                       ! (
                                          (chk < 0 && [type isEqualToString:@"prefix"]) || 
                                          (chk >= len && [type isEqualToString:@"suffix"]) || 
                                          [self isPunctuation:[fixed characterAtIndex:chk]]
                                          ) ^ isNegative
                                       ) {
                                        replace = FALSE;
                                        break;
                                    }
                                }
                                // Vowel
                                else if([scope isEqualToString:@"vowel"]) {
                                    if(
                                       ! (
                                          (
                                           (chk >= 0 && [type isEqualToString:@"prefix"]) || 
                                           (chk < len && [type isEqualToString:@"suffix"])
                                           ) && 
                                          [self isVowel:[fixed characterAtIndex:chk]]
                                          ) ^ isNegative
                                       ) {
                                        replace = FALSE;
                                        break;
                                    }
                                }
                                // Consonant
                                else if([scope isEqualToString:@"consonant"]) {
                                    if(
                                       ! (
                                          (
                                           (chk >= 0 && [type isEqualToString:@"prefix"]) || 
                                           (chk < len && [type isEqualToString:@"suffix"])
                                           ) && 
                                          [self isConsonant:[fixed characterAtIndex:chk]]
                                          ) ^ isNegative
                                       ) {
                                        replace = FALSE;
                                        break;
                                    }
                                }
                                // Exact
                                else if([scope isEqualToString:@"exact"]) {
                                    NSInteger s, e;
                                    if([type isEqualToString:@"suffix"]) {
                                        s = end;
                                        e = end + value.length;
                                    } 
                                    // Prefix
                                    else {
                                        s = start - value.length;
                                        e = start;
                                    }
                                    if(![self isExact:value heystack:fixed start:(int)s end:(int)e not:isNegative]) {
                                        replace = FALSE;
                                        break;
                                    }
                                }
                            }
                            
                            if(replace) {
                                [output appendString:rule[@"replace"]];
                                [output appendString:@"(্[যবম])?(্?)([ঃঁ]?)"];
                                cur = end - 1;
                                matched = TRUE;
                                break;
                            }
                            
                        }
                        
                        if(matched == TRUE) break;
                        
                        // Default
                        [output appendString:pattern[@"replace"]];
                        [output appendString:@"(্[যবম])?(্?)([ঃঁ]?)"];
                        cur = end - 1;
                        matched = TRUE;
                        break;
                    }
                    else if (find.length > chunk.length || 
                             (find.length == chunk.length && [find compare:chunk] == NSOrderedAscending)) {
                        left = mid + 1;
                    } else {
                        right = mid - 1;
                    }
                }
                if(matched == TRUE) break;                
            }
        }
        
        if(!matched) {
            unichar oldChar = [fixed characterAtIndex:cur];
            [output appendString:[NSString stringWithCharacters:&oldChar length:1]];
        }
        // NSLog(@"cur: %s, start: %s, end: %s, prev: %s\n", cur, start, end, prev);
    }
    
    
    return output;
}

- (BOOL)isVowel:(unichar)c {
    // Making it lowercase for checking
    c = [self smallCap:c];
    NSInteger i, len = _vowel.length;
    for (i = 0; i < len; ++i) {
        if ([_vowel characterAtIndex:i] == c) {
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)isConsonant:(unichar)c {
    // Making it lowercase for checking
    c = [self smallCap:c];
    NSInteger i, len = _consonant.length;
    for (i = 0; i < len; ++i) {
        if ([_consonant characterAtIndex:i] == c) {
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)isPunctuation:(unichar)c {
    return !([self isVowel:c] || [self isConsonant:c]);
}

- (BOOL)isCaseSensitive:(unichar)c {
    // Making it lowercase for checking
    c = [self smallCap:c];
    NSInteger i, len = _casesensitive.length;
    for (i = 0; i < len; ++i) {
        if ([_casesensitive characterAtIndex:i] == c) {
            return TRUE;
        }
    }
    return FALSE;
}

- (BOOL)isExact:(NSString*) needle heystack:(NSString*)heystack start:(int)start end:(int)end not:(BOOL)not {
    int len = end - start;
    return ((start >= 0 && end < heystack.length 
             && [[heystack substringWithRange:NSMakeRange(start, len)] isEqualToString:needle]) ^ not);
}

- (unichar)smallCap:(unichar) letter {
    if(letter >= 'A' && letter <= 'Z') {
        letter = letter - 'A' + 'a';
    }
    return letter;
}

- (NSString*)clean:(NSString *)string {
    NSMutableString* fixed = [[NSMutableString alloc] initWithCapacity:0];
    NSInteger i, len = string.length;
    for (i = 0; i < len; ++i) {
        unichar c = [string characterAtIndex:i];
        if (![self isCaseSensitive:c]) {
            [fixed appendFormat:@"%C", [self smallCap:c]];
        }
    }
    return fixed;
}

@end
