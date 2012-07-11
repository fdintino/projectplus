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
+ (SCMIcons*)sharedInstance;

- (void)redisplayProjectTrees;

- (void)registerSCMDelegate:(id <SCMIconDelegate>)delegate;

- (void)loadIconPacks;
- (NSDictionary*)iconPack;
- (NSOperationQueue*)operationQueue;
- (NSImage*)overlayIcon:(NSString*)name;

- (void)setSelectedIconPackIndex:(int)index;

- (NSString*)pathForVariable:(NSString*)shellVariableName paths:(NSArray*)paths;
@end
