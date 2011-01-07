#import "SCMIcons.h"

#define USE_THREADING

@interface GitIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary		*fileStatuses;
}
+ (GitIcons*)sharedInstance;
@end

static GitIcons *SharedInstance;

@implementation GitIcons
// ==================
// = Setup/Teardown =
// ==================
+ (GitIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

+ (void)load
{
	[[SCMIcons sharedInstance] registerSCMDelegate:[self sharedInstance]];
}

- (NSString*)scmName;
{
	return @"Git";
}

- (id)init
{
	if(SharedInstance)
	{
		[self release];
	}
	else if(self = SharedInstance = [[super init] retain])
	{
		fileStatuses = [[NSMutableDictionary alloc]init];
	}
	return SharedInstance;
}

- (void)dealloc
{
	[fileStatuses release];
	[super dealloc];
}

- (NSString*)gitPath;
{
	NSString	*path=[[SCMIcons sharedInstance] pathForVariable:@"TM_GIT" paths:[NSArray arrayWithObjects:@"/opt/local/bin/git",@"/usr/local/bin/git",@"/usr/bin/git",nil]];
	
	if(path && ![[NSFileManager defaultManager]fileExistsAtPath:path])
	{
		path=nil;
	}
	
	return path;
}

- (NSString *)gitRootForPath:(NSString *)path {
	
	if(!path) return nil;
	
	// NSLog(@"gitRootForPath: %@",path);
	
	NSFileManager	*fileManager=[NSFileManager defaultManager];
	NSString		*home=NSHomeDirectory();
	
	while(![fileManager fileExistsAtPath:[path stringByAppendingPathComponent:@".git"]])
	{
		path=[path stringByDeletingLastPathComponent];
		
		if([path isEqualToString:@"/"]) return nil;
		if([path isEqualToString:home]) return nil;
	}
	
	// NSLog(@"gitRootForPath is: %@",path);
	
	return path;
}

- (void)executeLsFilesUnderPath:(NSString*)path
{
	// NSLog(@"executeLsFilesUnderPath:  path: %@  (%@)",path,self);
	
	if(!path) return;
	
	NSString* exePath = [self gitPath];
	if(!exePath) return;
	
	@try
	{
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:path];
		if(path)
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", path, nil]];
		else
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", nil]];

		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		[task setStandardError:[NSPipe pipe]]; // Prevent errors from being printed to the Console

		NSFileHandle *file = [pipe fileHandleForReading];

		[task launch];

		NSData *data = [file readDataToEndOfFile];

		[task waitUntilExit];

		if([task terminationStatus] != 0)
		{
			return;
		}
		
		NSString 				*string=[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
		NSArray					*lines=[string componentsSeparatedByString:@"\0"];
		
		if([lines count] > 1)
		{
			for(int index = 0; index < [lines count]; index++)
			{
				NSString* line = [lines objectAtIndex:index];
				if([line length] > 3)
				{
					const char* statusChar = [[line substringToIndex:1] UTF8String];
					NSString* filename     = [line substringFromIndex:2];
					SCMIconsStatus status = SCMIconsStatusUnknown;
					
					if(!filename || [filename length]<1) continue;
					
					filename     = [path stringByAppendingPathComponent:filename];
					
					switch(*statusChar)
					{
						case 'H': status = SCMIconsStatusVersioned; break;
						case 'C': status = SCMIconsStatusModified; break;
						case 'R': status = SCMIconsStatusDeleted; break;
					}
					[fileStatuses setObject:[NSNumber numberWithInt:status] forKey:filename];
					// NSLog(@"%@: %d",filename,status);
				}
			}
		}
	}
	@catch(NSException* exception)
	{
		NSLog(@"executeLsFilesUnderPath caught exception: %@",exception);
	}
	
	//
	// Fallback for uncontrolled files
	// 
	[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusUnknown] forKey:path];
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload
{
	// NSLog(@"%s  path: %@  projectPath: %@  reload: %d",_cmd,path,projectPath,reload);
	
	if(!path) return SCMIconsStatusUnknown;
	
	NSNumber	*sn=nil;
	
	if(!reload)
	{
		sn=[fileStatuses objectForKey:path];
		
		if(sn) return (SCMIconsStatus)[sn intValue];
	}
	
	NSString	*gitRoot=[self gitRootForPath:path];
	
	// NSLog(@"gitRoot: %@",gitRoot);
	
	if(!gitRoot)
	{
		[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusUnknown] forKey:path];
		
		return SCMIconsStatusUnknown;
	}
	
	if(!reload)
	{
		//
		// Uncontrolled file?
		// 
		sn=[fileStatuses objectForKey:gitRoot];
	
		if(sn) return (SCMIconsStatus)[sn intValue];
	}
	
	//
	// Nope, get git statuses for gitRoot
	// 
	[self executeLsFilesUnderPath:gitRoot];
	
	sn=[fileStatuses objectForKey:path];
	
	if(!sn)
	{
		[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusUnknown] forKey:path];
		
		return SCMIconsStatusUnknown;
	}
	
	return (SCMIconsStatus)[sn intValue];
}

- (void)reloadStatusesForProject:(NSString*)projectPath
{
	// NSLog(@"reloadStatusesForProject, projectPath: %@",projectPath);
	
	NSMutableDictionary	*newStatuses=[[NSMutableDictionary alloc]init];
	
	for(NSString *key in fileStatuses)
	{
		if(![key hasPrefix:projectPath])
		{
			[newStatuses setObject:[fileStatuses objectForKey:key]forKey:key];
		}
	}
	
	id	old=fileStatuses;
	fileStatuses=newStatuses;
	[old release];
	
	[[SCMIcons sharedInstance] redisplayProjectTrees];
}

@end
