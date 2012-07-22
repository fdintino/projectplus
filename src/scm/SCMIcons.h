#import <Cocoa/Cocoa.h>
#import "TextMate.h"

enum SCMIconsStatus {
    SCMIconsStatusVersioned = 1,
    SCMIconsStatusModified,
    SCMIconsStatusAdded,
    SCMIconsStatusDeleted,
    SCMIconsStatusConflicted,
    SCMIconsStatusUnversioned,
    SCMIconsStatusUnknown,
    SCMIconsStatusRoot = 0x1000,
    SCMIconsStatusAhead = 0x2000,
    SCMIconsStatusBehind = 0x4000,
};

@protocol SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
- (NSString*)scmName;
@end
// Optional methods:
// - (void)reloadStatusesForProject:(NSString*)projectPath;

@interface SCMIcons : NSWindowController
{
    NSMutableArray* delegates;
    NSMutableArray* iconPacks;
    IBOutlet NSArrayController* iconPacksController;
    NSOperationQueue *operationQueue;
}
# pragma mark Setup / Teardown
+ (SCMIcons*)sharedInstance;
- (id)init;
- (NSOperationQueue*)operationQueue;
- (BOOL)scmIsEnabled:(NSString*)scmName;
- (void)setScm:(NSString*)scmName isEnabled:(BOOL)enabled;
- (void)redisplayProjectTrees;
- (void)registerSCMDelegate:(id <SCMIconDelegate>)delegate;
- (void)awakeFromNib;
- (void)dealloc;
# pragma mark -
# pragma mark Icons
- (NSDictionary*)iconPackNamed:(NSString*)iconPackName;
- (void)loadIconPacks;
- (NSDictionary*)iconPack;
- (NSImage*)overlayIcon:(NSString*)name;
- (NSImage *)projectIconNamed:(NSString *)overlayName forScmNamed:(NSString *)scmName;
- (NSImage*)imageForStatusCode:(SCMIconsStatus)status;
- (void)observeValueForKeyPath:(NSString*)key ofObject:(id)object change:(NSDictionary*)changes context:(void*)context;
- (void)setSelectedIconPackIndex:(int)index;
#pragma mark -
# pragma mark Delegate notifications/requests
- (void)reloadStatusesForAllProjects:(BOOL)reload;
- (void)reloadStatusesForProject:(NSString*)projectPath;
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload scmName:(NSString **)scmName;
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
- (int)numberOfRowsInTableView:(NSTableView*)tableView;
- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex;
- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex;
- (void)tableView:(NSTableView*)tableView setObjectValue:(id)value forTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex;
# pragma mark -
# pragma mark Utility methods
- (NSString*)pathForVariable:(NSString*)shellVariableName paths:(NSArray*)paths;
@end
