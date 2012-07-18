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
		
	int			projectStatus=SCMIconsStatusRoot;
	
	@try
	{
		{
			NSTask			*task=[[NSTask alloc]init];
			
			[task setLaunchPath:exePath];
			[task setCurrentDirectoryPath:path];
			
			[task setArguments:[NSArray arrayWithObjects:@"status",@"-bsuno",nil]];
			
			NSPipe			*pipe=[NSPipe pipe];
			[task setStandardOutput:pipe];
			[task setStandardError:[NSPipe pipe]]; // Prevent errors from being printed to the Console

			NSFileHandle	*file=[pipe fileHandleForReading];
			
			[task launch];
			
			NSData			*data=[file readDataToEndOfFile];
			
			[task waitUntilExit];
			[task release];
			
			if(data)
			{
				NSString 	*string=[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
				
				NSRange		r=[string rangeOfString:@"ahead" options:NSCaseInsensitiveSearch];
				
				if(r.location!=NSNotFound) projectStatus|=SCMIconsStatusAhead;
				
				r=[string rangeOfString:@"behind" options:NSCaseInsensitiveSearch];
				if(r.location!=NSNotFound) projectStatus|=SCMIconsStatusBehind;
			}
		}
		
		
		NSTask			*task=[[NSTask alloc]init];
		[task setLaunchPath:exePath];
		[task setCurrentDirectoryPath:path];
		if(path)
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", @"-o", path, nil]];
		else
			[task setArguments:[NSArray arrayWithObjects:@"ls-files", @"--exclude-standard", @"-z", @"-t", @"-m", @"-c", @"-d", @"-o", nil]];

		NSPipe *pipe = [NSPipe pipe];
		[task setStandardOutput: pipe];
		[task setStandardError:[NSPipe pipe]]; // Prevent errors from being printed to the Console

		NSFileHandle *file = [pipe fileHandleForReading];

		[task launch];

		NSData		*data = [file readDataToEndOfFile];

		[task waitUntilExit];
		int			terminationStatus=[task terminationStatus];
		
		[task release];
		
		if(terminationStatus != 0)
		{
			return;
		}
		
		NSString 				*string=[[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding]autorelease];
		NSArray					*lines=[string componentsSeparatedByString:@"\0"];
		@synchronized(fileStatuses)
		{
			if([lines count] > 1)
			{
				for(int index = 0; index < [lines count]; index++)
				{
					NSString* line = [lines objectAtIndex:index];
					if([line length] <= 3) {
						continue;
					}
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
						case '?': status = SCMIconsStatusUnversioned; break;
					}
					[fileStatuses setObject:[NSNumber numberWithInt:status] forKey:filename];
					
					if(status==SCMIconsStatusModified || status==SCMIconsStatusDeleted)
					{
						projectStatus|=SCMIconsStatusModified;
						
						//
						// Set folder state!
						// 
						filename=[filename stringByDeletingLastPathComponent];
						NSDictionary *folderAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
						if ([folderAttributes objectForKey:NSFileType] == NSFileTypeSymbolicLink) {
							filename = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: filename error:nil];
						}
						
						while(![filename isEqualToString:path] && !([filename length] > 1))
						{
							[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusModified] forKey:filename];
							filename=[filename stringByDeletingLastPathComponent];
							NSDictionary *folderAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filename error:nil];
							if ([folderAttributes objectForKey:NSFileType] == NSFileTypeSymbolicLink) {
								filename = [[NSFileManager defaultManager] destinationOfSymbolicLinkAtPath: filename error:nil];
							}
						}
					}
					
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
	// Status for git root
	// 
	// [fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusRoot] forKey:path];
	[fileStatuses setObject:[NSNumber numberWithInt:projectStatus] forKey:path];
}

- (void)executeLsFilesForProject:(NSString*)projectPath;
{
	NSAutoreleasePool* pool = [NSAutoreleasePool new];
	[self executeLsFilesUnderPath:projectPath];
	[self performSelectorOnMainThread:@selector(redisplayStatuses) withObject:nil waitUntilDone:NO];
	[pool release];
}

// SCMIconDelegate
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload
{
	// NSLog(@"%s  path: %@  projectPath: %@  reload: %d",_cmd,path,projectPath,reload);
	
	if(!path) return SCMIconsStatusUnknown;
	
	NSNumber	*status=nil;
	if(!reload)
	{
		status=[fileStatuses objectForKey:path];
		if(status) return (SCMIconsStatus)[status intValue];
	}
	
	NSString	*gitRoot=[self gitRootForPath:path];
	
	// NSLog(@"gitRoot: %@",gitRoot);
	
	if(!gitRoot)
	{
		//
		// Uncontrolled file?
		// 
		[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusUnknown] forKey:path];
		
		return SCMIconsStatusUnknown;
	}
	
	if(!reload)
	{
		//
		// Uncontrolled file?
		// 
		status=[fileStatuses objectForKey:gitRoot];
	
		if(status) return SCMIconsStatusUnknown;
	}
	
	//
	// Nope, get git statuses for gitRoot
	// 
	[self executeLsFilesUnderPath:gitRoot];
	
	status=[fileStatuses objectForKey:path];
	
	if(!status)
	{
		[fileStatuses setObject:[NSNumber numberWithInt:SCMIconsStatusUnknown] forKey:path];
		
		return SCMIconsStatusUnknown;
	}
	
	return (SCMIconsStatus)[status intValue];
}

- (void)redisplayStatuses;
{
	[[SCMIcons sharedInstance] redisplayProjectTrees];
}

- (void)reloadStatusesForProject:(NSString*)projectPath
{
    NSOperationQueue *operationQueue = [[SCMIcons sharedInstance] operationQueue];
    NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                            selector:@selector(executeLsFilesForProject:)
                                                                               object:projectPath];
    [operationQueue addOperation:operation];
    [operation release];
}

@end
