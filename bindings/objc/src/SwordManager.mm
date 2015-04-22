/*	SwordManager.mm - Sword API wrapper for Modules.

    Copyright 2008 Manfred Bergmann
    Based on code by Will Thimbleby

	This program is free software; you can redistribute it and/or modify it under the terms of the
	GNU General Public License as published by the Free Software Foundation version 2.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without
	even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
	General Public License for more details. (http://www.gnu.org/licenses/gpl.html)
*/

#import <ObjCSword/ObjCSword.h>
#import "Notifications.h"

#include "encfiltmgr.h"

using std::string;
using std::list;

@interface SwordManager ()

@property (strong, readwrite) NSDictionary *modules;

- (void)refreshModules;
- (void)addFiltersToModule:(SwordModule *)mod;

@end


@implementation SwordManager

# pragma mark - class methods

+ (NSArray *)moduleTypes {
    return @[SWMOD_TYPES_BIBLES, SWMOD_TYPES_COMMENTARIES, SWMOD_TYPES_DICTIONARIES, SWMOD_TYPES_GENBOOKS];
}

+ (SwordManager *)managerWithPath:(NSString *)path {
    SwordManager *manager = [[SwordManager alloc] initWithPath:path];
    return manager;
}

+ (SwordManager *)defaultManager {
    static SwordManager *instance = nil;
    if(instance == nil) {
        // use default path
        instance = [[SwordManager alloc] initWithPath:[[Configuration config] defaultModulePath]];
    }
    
	return instance;
}

- (id)initWithPath:(NSString *)path {

	if((self = [super init])) {
        // this is our main swManager
        self.temporaryManager = NO;
        
        self.modulesPath = path;

		self.modules = [NSDictionary dictionary];
		self.managerLock = (id) [[NSRecursiveLock alloc] init];

        [self reInit];
        
        sword::StringList options = swManager->getGlobalOptions();
        sword::StringList::iterator	it;
        for(it = options.begin(); it != options.end(); it++) {
            [self setGlobalOption:[NSString stringWithCString:it->c_str() encoding:NSUTF8StringEncoding] value:SW_OFF];
        }
    }	
	
	return self;
}

- (id)initWithSWMgr:(sword::SWMgr *)aSWMgr {
    self = [super init];
    if(self) {
        swManager = aSWMgr;
        // this is a temporary swManager
        self.temporaryManager = YES;
        
		self.modules = [NSDictionary dictionary];
        self.managerLock = (id) [[NSRecursiveLock alloc] init];
        
		[self refreshModules];
    }
    
    return self;
}


- (void)dealloc {
    if(!self.temporaryManager) {
        ALog(@"Deleting SWMgr!");
        delete swManager;
    }
}

- (void)reInit {
	[self.managerLock lock];
    if(self.modulesPath && [self.modulesPath length] > 0) {
        
        NSFileManager *fm = [NSFileManager defaultManager];
        if(![fm fileExistsAtPath:self.modulesPath]) {
            [self createModuleFolderTemplate];
        }

        // modulePath is the main sw manager
        swManager = new sword::SWMgr([self.modulesPath UTF8String], true, new sword::EncodingFilterMgr(sword::ENC_UTF8));

        if(!swManager) {
            ALog(@"Cannot create SWMgr instance for default module path!");
        } else {
            NSArray *subDirs = [fm contentsOfDirectoryAtPath:self.modulesPath error:NULL];
            // for all sub directories add module
            BOOL directory;
            NSString *fullSubDir;
            NSString *subDir;
            for(subDir in subDirs) {
                // as long as it's not hidden
                if(![subDir hasPrefix:@"."] && 
                   ![subDir isEqualToString:@"InstallMgr"] && 
                   ![subDir isEqualToString:@"mods.d"] &&
                   ![subDir isEqualToString:@"modules"]) {
                    fullSubDir = [self.modulesPath stringByAppendingPathComponent:subDir];
                    fullSubDir = [fullSubDir stringByStandardizingPath];
                    
                    //if its a directory
                    if([fm fileExistsAtPath:fullSubDir isDirectory:&directory]) {
                        if(directory) {
                            DLog(@"Augmenting folder: %@", fullSubDir);
                            swManager->augmentModules([fullSubDir UTF8String]);
                            DLog(@"Augmenting folder done");
                        }
                    }
                }
            }
            
            // clear some data
            [self refreshModules];
            
            SendNotifyModulesChanged(NULL);
        }
    }
	[self.managerLock unlock];
}

- (void)createModuleFolderTemplate {
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm createDirectoryAtPath:self.modulesPath withIntermediateDirectories:NO attributes:nil error:NULL];
    [fm createDirectoryAtPath:[self.modulesPath stringByAppendingPathComponent:@"mods.d"] withIntermediateDirectories:NO attributes:nil error:NULL];
    [fm createDirectoryAtPath:[self.modulesPath stringByAppendingPathComponent:@"modules"] withIntermediateDirectories:NO attributes:nil error:NULL];
}

- (void)addModulesPath:(NSString *)path {
	[self.managerLock lock];
	if(swManager == nil) {
		swManager = new sword::SWMgr([path UTF8String], true, new sword::EncodingFilterMgr(sword::ENC_UTF8));
    } else {
		swManager->augmentModules([path UTF8String]);
    }
	
	[self refreshModules];
	[self.managerLock unlock];
    
    SendNotifyModulesChanged(NULL);
}

- (void)refreshModules {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    // loop over modules
    sword::SWModule *mod;
	for(sword::ModMap::iterator it = swManager->Modules.begin(); it != swManager->Modules.end(); it++) {
		mod = it->second;

        if(mod) {
            // temporary instance
            SwordModule *swMod = [SwordModule moduleForSWModule:mod];
            NSString *type = [swMod typeString];

            ModuleType aType = [SwordModule moduleTypeForModuleTypeString:type];
            SwordModule *sm = [SwordModule moduleForType:aType swModule:mod swordManager:self];
            dict[[[sm name] lowercaseString]] = sm;

            [self addFiltersToModule:sm];
        }
	}

    // set modules
    self.modules = dict;
}

- (void)addFiltersToModule:(SwordModule *)mod {
    // prepare display filters

    id<FilterProvider> filterProvider = [[FilterProviderFactory providerFactory] get];

    switch([mod swModule]->getMarkup()) {
        case sword::FMT_GBF:
            if(!gbfFilter) {
                gbfFilter = [filterProvider newGbfRenderFilter];
            }
            if(!gbfStripFilter) {
                gbfStripFilter = [filterProvider newGbfPlainFilter];
            }
            [mod addRenderFilter:gbfFilter];
            [mod addStripFilter:gbfStripFilter];
            break;
        case sword::FMT_THML:
            if(!thmlFilter) {
                thmlFilter = [filterProvider newThmlRenderFilter];
            }
            if(!thmlStripFilter) {
                thmlStripFilter = [filterProvider newThmlPlainFilter];
            }
            [mod addRenderFilter:thmlFilter];
            [mod addStripFilter:thmlStripFilter];
            break;
        case sword::FMT_OSIS:
            if(!osisFilter) {
                osisFilter = [filterProvider newOsisRenderFilter];
            }
            if(!osisStripFilter) {
                osisStripFilter = [filterProvider newOsisPlainFilter];
            }
            [mod addRenderFilter:osisFilter];
            [mod addStripFilter:osisStripFilter];
            break;
        case sword::FMT_TEI:
            if(!teiFilter) {
                teiFilter = [filterProvider newTeiRenderFilter];
            }
            if(!teiStripFilter) {
                teiStripFilter = [filterProvider newTeiPlainFilter];
            }
            [mod addRenderFilter:teiFilter];
            [mod addStripFilter:teiStripFilter];
            break;
        case sword::FMT_PLAIN:
        default:
            if(!plainFilter) {
                plainFilter = [filterProvider newOsisPlainFilter];
            }
            [mod addRenderFilter:plainFilter];
            break;
    }
}

- (SwordModule *)moduleWithName:(NSString *)name {
    
	SwordModule	*ret = self.modules[[name lowercaseString]];
    if(ret == nil) {
        sword::SWModule *mod = [self getSWModuleWithName:name];
        if(mod == NULL) {
            ALog(@"No module by that name: %@!", name);
        } else {
            // temporary instance
            SwordModule *swMod = [SwordModule moduleForSWModule:mod];
            NSString *type = [swMod typeString];
            
            ModuleType aType = [SwordModule moduleTypeForModuleTypeString:type];
            ret = [SwordModule moduleForType:aType swModule:mod swordManager:self];

            if(ret != nil) {
                NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.modules];
                dict[[name lowercaseString]] = ret;
                self.modules = dict;                
            }
        }        
    }
    
	return ret;
}

- (void)setCipherKey:(NSString *)key forModuleNamed:(NSString *)name {
	[self.managerLock lock];
	swManager->setCipherKey([name UTF8String], [key UTF8String]);
	[self.managerLock unlock];
}

#pragma mark - module access

- (void)setGlobalOption:(NSString *)option value:(NSString *)value {
	[self.managerLock lock];
    swManager->setGlobalOption([option UTF8String], [value UTF8String]);
	[self.managerLock unlock];
}

- (BOOL)globalOption:(NSString *)option {
    return [[NSString stringWithUTF8String:swManager->getGlobalOption([option UTF8String])] isEqualToString:SW_ON];
}

- (NSArray *)listModules {
    return [self.modules allValues];
}
- (NSArray *)moduleNames {
    return [self.modules allKeys];
}

- (NSArray *)sortedModuleNames {
    return [[self moduleNames] sortedArrayUsingSelector:@selector(compare:)];
}

- (NSArray *)modulesForFeature:(NSString *)feature {
    NSMutableArray *ret = [NSMutableArray array];
    for(SwordModule *mod in [self.modules allValues]) {
        if([mod hasFeature:feature]) {
            [ret addObject:mod];
        }
    }
	
    // sort
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]];
    [ret sortUsingDescriptors:sortDescriptors];

	return [NSArray arrayWithArray:ret];
}

- (NSArray *)modulesForType:(ModuleType)type {
    NSMutableArray *ret = [NSMutableArray array];
    for(SwordModule *mod in [self.modules allValues]) {
        if([mod type] == type || type == All) {
            [ret addObject:mod];
        }
    }
    
    // sort
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]];
    [ret sortUsingDescriptors:sortDescriptors];
    
	return [NSArray arrayWithArray:ret];
}

- (NSArray *)modulesForCategory:(ModuleCategory)cat {
    NSMutableArray *ret = [NSMutableArray array];
    for(SwordModule *mod in [self.modules allValues]) {
        if([mod category] == cat) {
            [ret addObject:mod];
        }
    }
    
    // sort
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]];
    [ret sortUsingDescriptors:sortDescriptors];
    
	return [NSArray arrayWithArray:ret];    
}

#pragma mark - lowLevel methods

- (sword::SWMgr *)swManager {
    return swManager;
}

- (sword::SWModule *)getSWModuleWithName:(NSString *)moduleName {
	sword::SWModule *module;

	[self.managerLock lock];
	module = swManager->Modules[[moduleName UTF8String]];	
	[self.managerLock unlock];
    
	return module;
}

@end
