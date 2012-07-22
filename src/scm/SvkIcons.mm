#import "SCMIcons.h"

#define USE_THREADING

@interface SvkIcons : NSObject <SCMIconDelegate>
{
    NSMutableDictionary* projectStatuses;
    BOOL refreshingProject;
}
+ (SvkIcons*)sharedInstance;
@end

static SvkIcons *SharedInstance;

@implementation SvkIcons
// ==================
// = Setup/Teardown =
// ==================
+ (SvkIcons*)sharedInstance
{
    return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
    [[SCMIcons sharedInstance] registerSCMDelegate:[self sharedInstance]];
}

- (NSString*)scmName;
{
    return @"Svk";
}

- (id)init
{
    if (SharedInstance) {
        [self release];
    } else if (self = SharedInstance = [[super init] retain]) {
        projectStatuses = [NSMutableDictionary new];
    }
    return SharedInstance;
}

- (void)dealloc
{
    [projectStatuses release];
    [super dealloc];
}

- (NSString*)svkPath;
{
    return [[SCMIcons sharedInstance] pathForVariable:@"TM_SVK" paths:[NSArray arrayWithObjects:@"/opt/local/bin/svk",@"/usr/local/bin/svk",@"/usr/bin/svk",nil]];
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath;
{
    NSString* exePath = [self svkPath];
    if (!exePath || ![[NSFileManager defaultManager] fileExistsAtPath:exePath]) {
        return;
    }

    @try
    {
        NSTask* task = [[NSTask new] autorelease];
        [task setLaunchPath:exePath];
        [task setCurrentDirectoryPath:projectPath];
        if (path) {
            [task setArguments:[NSArray arrayWithObjects:@"status", @"-v", nil]];
        } else {
            [task setArguments:[NSArray arrayWithObjects:@"status", @"-v", path, nil]];
        }
        NSPipe *pipe = [NSPipe pipe];
        [task setStandardOutput: pipe];
        [task setStandardError:[NSPipe pipe]];

        NSFileHandle *file = [pipe fileHandleForReading];

        [task launch];

        NSData *data = [file readDataToEndOfFile];

        [task waitUntilExit];

        if ([task terminationStatus] != 0) {
            // Prevent repeated calling
            [projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
            return;
        }

        NSString *string             = [[[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding] autorelease];
        NSArray* lines               = [string componentsSeparatedByString:@"\n"];
        NSMutableDictionary* project = [[NSMutableDictionary alloc] initWithCapacity:([lines count]>0) ? ([lines count]-1) : 0];
        if ([lines count] > 1) {
            for (int index = 0; index < [lines count]; index++) {
                NSString* line = [lines objectAtIndex:index];
                if ([line length] > 3) {
                    const char* statusChar = [[line substringToIndex:1] UTF8String];
                    NSString* filename     = [projectPath stringByAppendingPathComponent:[line substringFromIndex:35]];
                    SCMIconsStatus status  = SCMIconsStatusUnknown;
                    switch(*statusChar) {
                        case ' ': status = SCMIconsStatusVersioned; break;
                        case 'M': status = SCMIconsStatusModified; break;
                        case 'A': status = SCMIconsStatusAdded; break;
                        case 'C': status = SCMIconsStatusConflicted; break;
                        case 'D': status = SCMIconsStatusDeleted; break;
                    }
                    [project setObject:[NSNumber numberWithInt:status] forKey:filename];
                }
            }
        }
        [projectStatuses setObject:project forKey:projectPath];
        [project release];
    }
    @catch(NSException* exception)
    {
        NSLog(@"%s %@: launch path \"%@\"", _cmd, exception, exePath);
        [projectStatuses setObject:[NSDictionary dictionary] forKey:projectPath];
    }
}

- (void)executeLsFilesForProject:(NSString*)projectPath;
{
    NSAutoreleasePool* pool = [NSAutoreleasePool new];
    [self executeLsFilesUnderPath:nil inProject:projectPath];
    [self performSelectorOnMainThread:@selector(redisplayStatuses) withObject:nil waitUntilDone:NO];
    [pool release];
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
{
    if (reload || ![projectStatuses objectForKey:projectPath]) {
        [self executeLsFilesUnderPath:path inProject:projectPath];
    }

    NSNumber* status = [[projectStatuses objectForKey:projectPath] objectForKey:path];
    if (status) {
        return (SCMIconsStatus)[status intValue];
    } else {
        return SCMIconsStatusUnknown;
    }
}

- (void)redisplayStatuses;
{
    refreshingProject = YES;
    [[SCMIcons sharedInstance] redisplayProjectTrees];
    refreshingProject = NO;
}

- (void)reloadStatusesForProject:(NSString*)projectPath;
{
#ifdef USE_THREADING
    NSOperationQueue *operationQueue = [[SCMIcons sharedInstance] operationQueue];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                            selector:@selector(executeLsFilesForProject:)
                                                                              object:projectPath];
    [operationQueue addOperation:operation];
    [operation release];
#else
    [projectStatuses removeObjectForKey:projectPath];
    [self executeLsFilesUnderPath:nil inProject:projectPath];
#endif
}
@end
