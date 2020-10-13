//
//  CCBPublishLuaBindingScript.m
//  CocosBuilder
//
//  Created by zhengle on 14-11-20.
//
//

#import "CCBPublishLuaBindingScript.h"
#import "CCBReaderInternalV1.h"

enum {
    kCCBTargetTypeNone = 0,
    kCCBTargetTypeDocumentRoot = 1,
    kCCBTargetTypeOwner = 2,
};

@implementation CCBPublishLuaBindingScript

+ (NSString*) getClassName:(NSDictionary*) doc
{
    NSDictionary* nodeGraph = [doc objectForKey:@"nodeGraph"];
    NSString* className = [nodeGraph objectForKey:@"jsController"];
    if ( ! className || ! className.length) {
        return nil;
    }
    
    //get last component of className
    NSRange range = [className rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location != NSNotFound)
    {
        className = [className substringFromIndex:range.location + 1];
    }
    
    return className;
}

+ (NSString*) exportString:(NSDictionary*) doc ccbiName:(NSString*)ccbiName
{
    NSDictionary* nodeGraph = [doc objectForKey:@"nodeGraph"];
    NSString* className = [nodeGraph objectForKey:@"jsController"];
    NSString* ccbiFolder = @"ccb";
    if ( ! className || ! className.length) {
        return nil;
    }
    
    //get last component of className
    NSRange range = [className rangeOfString:@"." options:NSBackwardsSearch];
    if (range.location != NSNotFound)
    {
        ccbiFolder = [NSString stringWithFormat:@"%@/%@", ccbiFolder, [className substringToIndex:range.location]];
        ccbiFolder = [ccbiFolder stringByReplacingOccurrencesOfString:@"." withString:@"/"];
        className = [className substringFromIndex:range.location + 1];
    }
    if ( ! className || ! className.length) {
        return nil;
    }
    
    ccbiName = [NSString stringWithFormat:@"ccb/%@.ccbi", ccbiName];
    
    // load templates
    NSString* classTemplatePath = [[[NSBundle mainBundle] resourcePath] stringByAppendingString:@"/luaTemplate/class_template.lua"];
    NSString* functionTemplatePath = [[classTemplatePath stringByDeletingLastPathComponent] stringByAppendingString:@"/function_template.lua"];

    NSString* classTemplate = [NSString stringWithContentsOfFile:classTemplatePath encoding:NSUTF8StringEncoding error:nil];
    NSString* functionTemplate = [NSString stringWithContentsOfFile:functionTemplatePath encoding:NSUTF8StringEncoding error:nil];
    
    // load functions & members
    NSMutableArray* funcs = [NSMutableArray array];
    NSMutableArray* members = [NSMutableArray array];
    [CCBPublishLuaBindingScript fillFuncs:nodeGraph funcs:funcs members:members];
    
    // functions
    NSString* funcNameReplacement = @"";
    NSString* funcImplementReplacement = @"";
    for (NSArray* func in funcs) {
        NSString* funcName = [func objectAtIndex:0];
        NSNumber* target  = [func objectAtIndex:1];
        // build names
        if (funcNameReplacement.length > 0)
        {
            funcNameReplacement = [funcNameReplacement stringByAppendingString:@"\n    "];
        }
        if ([target intValue] == kCCBTargetTypeDocumentRoot) {
            funcNameReplacement = [funcNameReplacement stringByAppendingFormat:@"\"%@\",", funcName];
        }else if ([target intValue] == kCCBMemberVarAssignmentTypeOwner) {
            funcNameReplacement = [funcNameReplacement stringByAppendingFormat:@"-- \"%@\", --[[ Owner ]]", funcName];
        }
        
        // build implements
        if (funcImplementReplacement.length > 0)
        {
            funcImplementReplacement = [funcImplementReplacement stringByAppendingString:@"\n\n"];
        }
        if ([target intValue] == kCCBTargetTypeDocumentRoot) {
            funcImplementReplacement = [funcImplementReplacement stringByAppendingString:[functionTemplate stringByReplacingOccurrencesOfString:@"__FUNC_NAME__" withString:funcName]];
        }else if ([target intValue] == kCCBMemberVarAssignmentTypeOwner) {
            funcImplementReplacement = [funcImplementReplacement stringByAppendingFormat:@"--[[\n-- Owner\n%@\n]]", [functionTemplate stringByReplacingOccurrencesOfString:@"__FUNC_NAME__" withString:funcName]];
        }
    }
    
    //members
    NSString* membersReplacement = @"";
    for (NSDictionary* node in members) {
        NSString* assignName = [node objectForKey:@"memberVarAssignmentName"];
        NSNumber* assignType = [node objectForKey:@"memberVarAssignmentType"];
        NSString* baseClass  = [node objectForKey:@"baseClass"];
        NSString* customClass= [node objectForKey:@"customClass"];
        
        if (membersReplacement.length > 0) {
            membersReplacement = [membersReplacement stringByAppendingString:@"\n    "];
        }
        
        if ([baseClass isEqualToString:@"CCBFile"]) {
            for (NSDictionary* prop in [node objectForKey:@"properties"]) {
                if ([[prop objectForKey:@"type"] isEqualToString:@"CCBFile"]) {
                    NSString* ccbPath = [prop objectForKey:@"value"];
                    
                    baseClass = [NSString stringWithFormat:@"CCBFile(%@i)", ccbPath];
//                    NSLog([NSString stringWithFormat:@"CCBFile: %@i", ccbPath]);
                }
            }
        }
        
        membersReplacement = [membersReplacement stringByAppendingFormat:@"%@.%@ %@",
                                    [assignType intValue] == kCCBMemberVarAssignmentTypeDocumentRoot ? @"self" : @"owner",
                                    assignName,
                                    customClass.length > 0 ? customClass : baseClass
                              ];
    }
    
    // replace contents
    NSString* content = classTemplate;
    
    content = [content stringByReplacingOccurrencesOfString:@"__CCBI_FILE_PATH__" withString:ccbiName];
    content = [content stringByReplacingOccurrencesOfString:@"__CCBI_FOLDER__" withString:ccbiFolder];
    content = [content stringByReplacingOccurrencesOfString:@"__FUNC_NAMES__" withString:funcNameReplacement];
    content = [content stringByReplacingOccurrencesOfString:@"__FUNC_IMPLEMENTS__" withString:funcImplementReplacement];
    content = [content stringByReplacingOccurrencesOfString:@"__MEMBERS__" withString:membersReplacement];
    content = [content stringByReplacingOccurrencesOfString:@"__CLASS_NAME__" withString:className];
    
    return content;
}

+ (void) fillFuncs:(NSDictionary*) node funcs:(NSMutableArray*) funcs members:(NSMutableArray*) members
{
    NSString* className = [node objectForKey:@"baseClass"];
//    NSLog(@"fillFuncs: %@", className);
    
    // push to fields
    NSString* assignName = [node objectForKey:@"memberVarAssignmentName"];
    NSNumber* assignType = [node objectForKey:@"memberVarAssignmentType"];
    if (assignName && assignName.length > 0 && [assignType intValue] != kCCBMemberVarAssignmentTypeNone) {
        [members addObject:node];
    }
    
    // push to funcs
    NSArray* classList = [NSArray arrayWithObjects:@"CCMenuItemImage", @"CCControl", @"CCControlButton", nil];
    if ([classList containsObject:className]) {
        //check property
        for (NSDictionary* prop in [node objectForKey:@"properties"]) {
            NSString* type = [prop objectForKey:@"type"];
            if ( ! [type isEqualToString:@"Block"] && ! [type isEqualToString:@"BlockCCControl"] ) continue;
            
            NSArray* value = (NSArray*)[prop objectForKey:@"value"];
            NSUInteger target = [value objectAtIndex:1];
            if (target != kCCBTargetTypeNone) {
                [funcs addObject:value];
            }
        }
        return;
    }
    
    // find children
    NSArray* children = [node objectForKey:@"children"];
    if ( ! children || ! children.count) {
        return;
    }
    
    for (NSDictionary* n in children) {
        [CCBPublishLuaBindingScript fillFuncs:n funcs:funcs members:members];
    }
}

+ (NSString*) getFolders:(NSDictionary*) doc inDir:(NSString*) luaDir
{
    NSDictionary* nodeGraph = [doc objectForKey:@"nodeGraph"];
    NSString* name = [nodeGraph objectForKey:@"jsController"];
    if ( ! name || ! name.length) {
        return luaDir;
    }
    
    name = [name stringByReplacingOccurrencesOfString:@"." withString:@"/"];
    name = [name stringByDeletingLastPathComponent];
    
    if ( ! name || name.length <= 0) {
        return luaDir;
    }
    
    name = [luaDir stringByAppendingPathComponent:name];
    BOOL isDir;
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if( ! [fileManager fileExistsAtPath:name isDirectory:&isDir])
    {
        if( ! [fileManager createDirectoryAtPath:name withIntermediateDirectories:YES attributes:nil error:NULL])
        {
            NSLog(@"Error: Create folder failed %@", name);
            return luaDir;
        }
    }
    
    return name;
}

@end
