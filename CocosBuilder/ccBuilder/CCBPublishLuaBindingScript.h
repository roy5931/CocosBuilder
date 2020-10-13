//
//  CCBPublishLuaBindingScript.h
//  CocosBuilder
//
//  Created by zhengle on 14-11-20.
//
//

#import <Foundation/Foundation.h>

@interface CCBPublishLuaBindingScript : NSObject

+ (NSString*) getClassName:(NSDictionary*) doc;
+ (NSString*) exportString:(NSDictionary*) doc ccbiName:(NSString*)name;
+ (NSString*) getFolders:(NSDictionary*) doc inDir:(NSString*) luaDir;
//+ (void) fillFuncs:(NSDictionary*) node funcNames:(NSMutableArray*) funcNames;

@end
