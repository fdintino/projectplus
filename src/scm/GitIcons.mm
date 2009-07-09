#import "SCMIcons.h"

#define USE_THREADING

@interface GitIcons : NSObject <SCMIconDelegate>
{
	NSMutableDictionary		*projectStatuses;
	BOOL					updateRunning;
	NSLock					*projectStatusesLock;
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
		projectStatusesLock=[[NSLock alloc]init];
		projectStatuses = [NSMutableDictionary new];
		updateRunning=NO;
	}
	return SharedInstance;
}

- (void)dealloc
{
	[projectStatuses release];
	[super dealloc];
}

- (NSString*)gitPath;
{
	return [[SCMIcons sharedInstance] pathForVariable:@"TM_GIT" paths:[NSArray arrayWithObjects:@"/opt/local/bin/git",@"/usr/local/bin/git",@"/usr/bin/git",nil]];
}

- (NSString *)gitRootForPath:(NSString *)path {
	
	if(!path) return nil;
	
	//
	// Check if we know the project for this file
	// 
	NSString	*p=path;
	
	while(![p isEqualToString:@"/"])
	{
		[projectStatusesLock lock];
		id o=[projectStatuses objectForKey:p];
		[projectStatusesLock unlock];
		if(o) return p;
		p=[p stringByDeletingLastPathComponent];
	}
	
	//
	// We don't know the project yet, try and find the root
	// 
	NSFileManager	*fileManager=[NSFileManager defaultManager];
	NSString		*home=NSHomeDirectory();
	
	while(![fileManager fileExistsAtPath:[path stringByAppendingPathComponent:@".git"]])
	{
		path=[path stringByDeletingLastPathComponent];
		
		if([path isEqualToString:@"/"]) return nil;
		if([path isEqualToString:home]) return nil;
	}
	
	return path;
}

- (void)executeLsFilesUnderPath:(NSString*)path inProject:(NSString*)projectPath
{
	// NSLog(@"%s  path: %@  projectPath: %@",_cmd,path,projectPath);
	
	if(!path || !projectPath) return;
	
	NSString* exePath = [self gitPath];
	if(!exePath || ![[NSFileManager defaultManager]fileExistsAtPath:exePath])
		return;
	
	@try
	{
		NSTask* task = [[NSTask new] autorelease];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:projectPath];
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
		
		[projectStatusesLock lock];
		
		NSString 				*string=[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
		NSArray					*lines=[string componentsSeparatedByString:@"\0"];
		NSMutableDictionary		*projectDict=[projectStatuses objectForKey:projectPath];
		
		if(!projectDict)
		{
			projectDict=[[NSMutableDictionary alloc]init];
			[projectStatuses setObject:projectDict forKey:projectPath];
			[projectDict release];
		}
		
		if([lines count] > 1)
		{
			for(int index = 0; index < [lines count]; index++)
			{
				NSString* line = [lines objectAtIndex:index];
				if([line length] > 3)
				{
					const char* statusChar = [[line substringToIndex:1] UTF8String];
					NSString* filename     = [projectPath stringByAppendingPathComponent:[line substringFromIndex:2]];
					SCMIconsStatus status = SCMIconsStatusUnknown;
					
					if(!filename || [filename length]<1) continue;
					
					switch(*statusChar)
					{
						case 'H': status = SCMIconsStatusVersioned; break;
						case 'C': status = SCMIconsStatusModified; break;
						case 'R': status = SCMIconsStatusDeleted; break;
					}
					[projectDict setObject:[NSNumber numberWithInt:status] forKey:filename];
				}
			}
		}
		
		[projectStatusesLock unlock];
	}
	@catch(NSException* exception)
	{
	}
}

- (void)executeLsFilesForProject:(NSString*)projectPath;
{
	if(updateRunning) return;
	
	updateRunning=YES;
	
	@try
	{
		NSAutoreleasePool* pool = [NSAutoreleasePool new];
		[self executeLsFilesUnderPath:projectPath inProject:projectPath];
		[self performSelectorOnMainThread:@selector(redisplayStatuses) withObject:nil waitUntilDone:NO];
		[pool release];
	}
	@finally
	{
		updateRunning=NO;
	}
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload
{
	// NSLog(@"%s  path: %@  projectPath: %@  reload: %d",_cmd,path,projectPath,reload);
	
	if(!path) return SCMIconsStatusUnknown;
	
	NSString	*project=[self gitRootForPath:path];
	
	// NSLog(@"project: %@",project);
	
	if(!project)
	{
		if(projectPath && [projectPath length]>1)
		{
			[projectStatusesLock lock];
			[projectStatuses setObject:[NSMutableDictionary dictionary] forKey:projectPath];
			[projectStatusesLock unlock];
		}
		
		return SCMIconsStatusUnknown;
	}
	
	[projectStatusesLock lock];
	id o=[projectStatuses objectForKey:project];
	[projectStatusesLock unlock];
	
	if(reload || !o)
	{
		if(!o)
		{
			// NSLog(@"will load project status");
			[projectStatusesLock lock];
			[projectStatuses setObject:[NSMutableDictionary dictionary] forKey:project];
			[projectStatusesLock unlock];
			[self executeLsFilesUnderPath:project inProject:project];
		}
		else
		{
			// NSLog(@"will load file status");
			[self executeLsFilesUnderPath:path inProject:project];
		}
	}
	
	[projectStatusesLock lock];
	NSNumber	*status=[[projectStatuses objectForKey:project]objectForKey:path];
	[projectStatusesLock unlock];
	
	if(!status) return SCMIconsStatusUnknown;
	
	return (SCMIconsStatus)[status intValue];
}

- (void)redisplayStatuses;
{
	[[SCMIcons sharedInstance] redisplayProjectTrees];
}

- (void)reloadStatusesForProject:(NSString*)projectPath
{
	// NSLog(@"%s  projectPath: %@",_cmd,projectPath);
	
	if(updateRunning) return;
	
	NSString	*project=[self gitRootForPath:projectPath];
	
	[projectStatusesLock lock];
	if(project) [projectStatuses removeObjectForKey:project];
	if(projectPath) [projectStatuses removeObjectForKey:projectPath];
	
	if(!project)
	{
		[projectStatuses setObject:[NSMutableDictionary dictionary] forKey:projectPath];
		[projectStatusesLock unlock];
		
		return;
	}
	
	[projectStatuses setObject:[NSMutableDictionary dictionary] forKey:project];
	[projectStatusesLock unlock];
	
#ifdef USE_THREADING
	[NSThread detachNewThreadSelector:@selector(executeLsFilesForProject:) toTarget:self withObject:project];
#else
	[self executeLsFilesUnderPath:project inProject:project];
#endif
}
@end
