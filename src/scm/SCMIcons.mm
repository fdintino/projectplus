#import "SCMIcons.h"
#import "ProjectPlus.h"
#import "TextMate.h"

#define LIST_OFFSET 		4
#define ICON_SIZE 		15
#define BADGE_SIZE		10

NSString* const overlayImageNames[] = {@"Modified", @"Added", @"Deleted", @"Versioned", @"Conflicted", @"Unversioned"};

@interface SCMIcons (Private)
- (void)reloadStatusesForAllProjects:(BOOL)reload;
- (void)reloadStatusesForProject:(NSString*)projectPath;
- (NSImage*)imageForStatusCode:(SCMIconsStatus)status;
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload;
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload scmName:(NSString **)scmName;
- (NSImage *)projectIconNamed:(NSString *)overlayName forScmNamed:(NSString *)scmName;
@end

@interface NSWindowController (SCMAppSwitching)
- (void)scmRefreshApplicationDidBecomeActiveNotification;
@end

@implementation NSWindowController (SCMAppSwitching)
- (void)scmRefreshApplicationDidBecomeActiveNotification
{
	[[SCMIcons sharedInstance] reloadStatusesForAllProjects:NO];
}
@end

@implementation NSOutlineView (SCMOutlineView)

- (void)drawOverlay:(NSString *)overlayName
	forScmNamed:(NSString *)scmName
	inRect:(NSRect)iconRect
	flip:(BOOL)flip
{
	
	NSImage	*image=[[SCMIcons sharedInstance]projectIconNamed:overlayName forScmNamed:scmName];
	
	if(image)
	{
		if(flip) [image setFlipped:YES];
		[image drawInRect:iconRect
                fromRect:NSZeroRect
               operation:NSCompositeSourceOver
                fraction:1];
		if(flip) [image setFlipped:NO];
	}
}

- (void)drawOverlayForRow:(int)rowNumber inProject:(NSString*)projectPath;
{
	NSDictionary* item = [self itemAtRow:rowNumber];

	if (item) {
		NSString* scmName=nil;
		NSString* path        = [item objectForKey:@"filename"];
		if (!path) path       = [item objectForKey:@"sourceDirectory"];
		SCMIconsStatus status = [[SCMIcons sharedInstance] statusForPath:path inProject:projectPath reload:NO scmName:&scmName];
		
		NSImage* overlay = [[SCMIcons sharedInstance] imageForStatusCode:status];
		if (overlay)
		{
			// NSAffineTransform* transform = [NSAffineTransform transform];
			// [transform rotateByDegrees:180];
			// [transform concat];
			[overlay setFlipped:YES];
			[overlay drawInRect:NSMakeRect(LIST_OFFSET + ([self levelForRow:rowNumber] + 1) * [self indentationPerLevel],
													rowNumber * ([self rowHeight] + [self intercellSpacing].height),
													ICON_SIZE, ICON_SIZE)
                    fromRect:NSZeroRect
                   operation:NSCompositeSourceOver
                    fraction:1];
			[overlay setFlipped:NO];
		}
		
		if(status&SCMIconsStatusRoot && scmName)
		{
			NSRect	iconRect=NSMakeRect(
				LIST_OFFSET + ([self levelForRow:rowNumber] + 1) * [self indentationPerLevel],
				rowNumber * ([self rowHeight] + [self intercellSpacing].height),
				ICON_SIZE,
				ICON_SIZE
			);
			
			[self drawOverlay:@"Root" forScmNamed:scmName inRect:iconRect flip:YES];
			
			if(status&SCMIconsStatusAhead) [self drawOverlay:@"Ahead" forScmNamed:scmName inRect:iconRect flip:YES];
			if(status&SCMIconsStatusBehind) [self drawOverlay:@"Behind" forScmNamed:scmName inRect:iconRect flip:YES];
		}
	}
}

- (void)scmDrawRect:(NSRect)rect
{
	[self scmDrawRect:rect];

	NSString* projectPath = [[self delegate] performSelector:@selector(findProjectDirectory)];
	NSRange rows          = [self rowsInRect:rect];
	int rowNumber         = rows.location;
	while (rowNumber <= rows.location + rows.length)
		[self drawOverlayForRow:rowNumber++ inProject:projectPath];
}
@end

@implementation NSWindow (NSWindowPoser)
- (void)drawOverlay:(NSString *)overlayName
        forScmNamed:(NSString *)scmName
             inRect:(NSRect)iconRect
               flip:(BOOL)flip
{
	
	NSImage	*image=[[SCMIcons sharedInstance]projectIconNamed:overlayName forScmNamed:scmName];
	
	if(image)
	{
		if(flip) [image setFlipped:YES];
		[image drawInRect:iconRect
                 fromRect:NSZeroRect
                operation:NSCompositeSourceOver
                 fraction:1];
		if(flip) [image setFlipped:NO];
	}
}
// called when the user switches tabs (or load files)
- (void)ProjectPlus_setRepresentedFilename:(NSString*)path
{
	[self ProjectPlus_setRepresentedFilename:path];

	if([[self delegate] isKindOfClass:OakProjectController])
	{
		NSString* scmName=nil;
		NSString* projectPath = [[self delegate] valueForKey:@"projectDirectory"];

		SCMIconsStatus status = [[SCMIcons sharedInstance] statusForPath:path inProject:projectPath reload:YES scmName:&scmName];
		NSImage* overlay      = [[SCMIcons sharedInstance] imageForStatusCode:status];

		NSImage* icon = [[[self standardWindowButton:NSWindowDocumentIconButton] image] copy];
		[icon lockFocus];

		[overlay drawInRect:NSMakeRect(0, 0, [icon size].width, [icon size].height)
	              fromRect:NSZeroRect
	             operation:NSCompositeSourceOver
	              fraction:1];
		
		if(status&SCMIconsStatusRoot && scmName)
		{
			NSRect	iconRect=NSMakeRect(0, 0, [icon size].width, [icon size].height);
			
			[self drawOverlay:@"Root" forScmNamed:scmName inRect:iconRect flip:NO];

			if(status&SCMIconsStatusAhead) [self drawOverlay:@"Ahead" forScmNamed:scmName inRect:iconRect flip:NO];
			if(status&SCMIconsStatusBehind) [self drawOverlay:@"Behind" forScmNamed:scmName inRect:iconRect flip:NO];
		}
		
		[icon unlockFocus];

		[[self standardWindowButton:NSWindowDocumentIconButton] setImage:icon];
		[icon release];
		
		// Update the tree as well, file status may have changed
		[[SCMIcons sharedInstance] redisplayProjectTrees];
	}
}
@end

static SCMIcons* SharedInstance;

@implementation SCMIcons
// ==================
// = Setup/Teardown =
// ==================
+ (SCMIcons*)sharedInstance
{
	return SharedInstance ?: [[self new] autorelease];
}

- (id)init
{
	if(SharedInstance)
	{
		[self release];
	}
	else if((self = SharedInstance = [[super init] retain]))
	{
		NSApp = [NSApplication sharedApplication];
		
		delegates = [[NSMutableArray alloc] initWithCapacity:1];

		operationQueue = [[NSOperationQueue alloc] init];

        [NSWindow jr_swizzleMethod:@selector(setRepresentedFilename:) withMethod:@selector(ProjectPlus_setRepresentedFilename:) error:NULL];

		[self loadIconPacks];

		[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:0] forKey:@"SCMMateSelectedIconPack"]];

		[NSClassFromString(@"OakOutlineView") jr_swizzleMethod:@selector(drawRect:) withMethod:@selector(scmDrawRect:) error:NULL];
	}
	return SharedInstance;
}

- (NSOperationQueue*) operationQueue {
    return operationQueue;
}

- (BOOL)scmIsEnabled:(NSString*)scmName;
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:[NSString stringWithFormat:@"ProjectPlus %@ Enabled", scmName]];
}

- (void)setScm:(NSString*)scmName isEnabled:(BOOL)enabled;
{
	[[NSUserDefaults standardUserDefaults] setBool:enabled forKey:[NSString stringWithFormat:@"ProjectPlus %@ Enabled", scmName]];
}

- (void)redisplayProjectTrees;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ProjectPlus_redrawRequired object:nil];
}

- (void)registerSCMDelegate:(id <SCMIconDelegate>)delegate;
{
	[delegates addObject:delegate];
	[self redisplayProjectTrees];
}

- (void)awakeFromNib
{
	[self setSelectedIconPackIndex:[[NSUserDefaults standardUserDefaults] integerForKey:@"SCMMateSelectedIconPack"]];
	[iconPacksController addObserver:self forKeyPath:@"selectionIndex" options:NULL context:NULL];
}

- (void)dealloc
{
	[delegates release];
	[iconPacks release];
    [operationQueue release];
	[super dealloc];
}

// =========
// = Icons =
// =========
- (NSDictionary*)iconPackNamed:(NSString*)iconPackName;
{
	size_t imageCount             = sizeof(overlayImageNames) / sizeof(NSString*);
	NSMutableDictionary* iconPack = [NSMutableDictionary dictionaryWithCapacity:imageCount];
	NSString* path                = [@"icons" stringByAppendingPathComponent:iconPackName];

	for(size_t index = 0; index < imageCount; index += 1)
	{
		NSString* imageName   = overlayImageNames[index];
		size_t imageTypeCount = [[NSImage imageFileTypes] count];

		for(size_t index = 0; index < imageTypeCount; index += 1)
		{
			NSString* imageType = [[NSImage imageFileTypes] objectAtIndex:index];

			if(NSString* imagePath = [[NSBundle bundleForClass:[SCMIcons class]] pathForResource:imageName ofType:imageType inDirectory:path])
			{
				if(NSImage* image = [[NSImage alloc] initByReferencingFile:imagePath])
				{
					// [image setFlipped:YES];
					[iconPack setObject:image forKey:imageName];
					[image release];
					break;
				}
			}
		}
	}
	return iconPack;
}

- (void)loadIconPacks;
{
	[iconPacks release];
	iconPacks = [[NSMutableArray alloc] initWithCapacity:5];
	
	// NSArray* iconPackNames = [NSArray arrayWithObjects:@"Straight",@"Classic",nil];
	NSString* iconsPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"icons" ofType:nil];
	NSDirectoryEnumerator* dirEnum = [[NSFileManager defaultManager] enumeratorAtPath:iconsPath];
	NSString* iconPackName;

	while((iconPackName = [dirEnum nextObject]))
	{
		[dirEnum skipDescendents];
		if([[dirEnum fileAttributes] objectForKey:NSFileType] == NSFileTypeDirectory)
		{
			NSDictionary* icons = [self iconPackNamed:iconPackName];
			if(icons && [icons count])
			{
				NSDictionary* iconPack = [NSDictionary dictionaryWithObjectsAndKeys:[self iconPackNamed:iconPackName],@"icons",iconPackName,@"name",nil];
				[iconPacks addObject:iconPack];
			}
		}
	}
}

- (NSDictionary*)iconPack;
{
	NSDictionary* iconPack = nil;
	int selectedIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"SCMMateSelectedIconPack"];

	if(selectedIndex < [[iconPacksController arrangedObjects] count])
		iconPack = [[[iconPacksController arrangedObjects] objectAtIndex:selectedIndex] objectForKey:@"icons"];

	return iconPack;
}

- (NSImage*)overlayIcon:(NSString*)name
{
	return [[self iconPack] objectForKey:name];
}

- (NSImage *)projectIconNamed:(NSString *)overlayName forScmNamed:(NSString *)scmName
{
	static NSMutableDictionary	*projectRootIcons=nil;
	
	if(!scmName) return nil;
	
	NSString	*imageName=[scmName stringByAppendingString:overlayName];
	NSImage		*image=[projectRootIcons objectForKey:imageName];
	
	if(!image)
	{
		if(!projectRootIcons) projectRootIcons=[[NSMutableDictionary alloc]init];
		
		NSString	*path=[[NSBundle bundleForClass:[SCMIcons class]]
			pathForImageResource:imageName
		];

		if(path)
		{
			image=[[NSImage alloc]initByReferencingFile:path];
		}
		
		if(!image) image=(NSImage *)[NSNull null];
		
		[projectRootIcons setObject:image forKey:imageName];
	}
	
	if(image==(NSImage *)[NSNull null]) return nil;
	
	return image;	
}

- (NSImage*)imageForStatusCode:(SCMIconsStatus)status
{
	int s=status;
	s&=0x3ff;
	
	switch(s)
	{
		case 0:
		case SCMIconsStatusVersioned:    return [self overlayIcon:@"Versioned"];
		case SCMIconsStatusModified:     return [self overlayIcon:@"Modified"];
		case SCMIconsStatusAdded:        return [self overlayIcon:@"Added"];
		case SCMIconsStatusDeleted:      return [self overlayIcon:@"Deleted"];
		case SCMIconsStatusConflicted:   return [self overlayIcon:@"Conflicted"];
		case SCMIconsStatusUnversioned:  return [self overlayIcon:@"Unversioned"];
	}

	return nil;
}

- (void)setSelectedIconPackIndex:(int)index
{
	[iconPacksController setSelectionIndex:index];
	[[NSUserDefaults standardUserDefaults] setInteger:index forKey:@"SCMMateSelectedIconPack"];
	[self redisplayProjectTrees];
}

- (void)observeValueForKeyPath:(NSString*)key ofObject:(id)object change:(NSDictionary*)changes context:(void*)context
{
	[self setSelectedIconPackIndex:[iconPacksController selectionIndex]];
}

// Delegate notifications/requests
- (void)reloadStatusesForAllProjects:(BOOL)reload;
{
	NSArray* windows = [NSApp windows];

	for(int index = 0; index < [windows count]; index++)
	{
		NSWindow* window = [windows objectAtIndex:index];
		if([window delegate] && [[window delegate] isKindOfClass:NSClassFromString(@"OakProjectController")])
		{
			NSWindowController *controller = (NSWindowController*)[window delegate];
			NSString *projectDirectory = [controller valueForKey:@"projectDirectory"];
			[self reloadStatusesForProject:projectDirectory];
		}
	}
    [operationQueue waitUntilAllOperationsAreFinished];
    if (reload == YES)
        [self redisplayProjectTrees];
	
}

- (void)reloadStatusesForProject:(NSString*)projectPath;
{
	for(int delegateIndex = 0; delegateIndex < [delegates count]; delegateIndex++)
	{
		id delegate = [delegates objectAtIndex:delegateIndex];
		if([self scmIsEnabled:[delegate scmName]] && [delegate respondsToSelector:@selector(reloadStatusesForProject:)])
		    [delegate reloadStatusesForProject:projectPath];
	}
}

- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload scmName:(NSString **)scmName
{
	if([path length] == 0)
		return SCMIconsStatusUnknown;

	for(int index = 0; index < [delegates count]; index++)
	{
		id delegate = [delegates objectAtIndex:index];
		if([self scmIsEnabled:[delegate scmName]])
		{
			SCMIconsStatus status = [delegate statusForPath:path inProject:projectPath reload:reload];
			if(status != SCMIconsStatusUnknown)
			{
				if(scmName) *scmName=[delegate scmName];
				return status;
			}
		}
	}
	return SCMIconsStatusUnknown;
}
- (SCMIconsStatus)statusForPath:(NSString*)path inProject:(NSString*)projectPath reload:(BOOL)reload
{
	return [self statusForPath:path inProject:projectPath reload:reload scmName:NULL]; 
}
- (int)numberOfRowsInTableView:(NSTableView*)tableView
{
	return [delegates count];
}

- (void)tableView:(NSTableView*)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex
{
	NSString* name = [[delegates objectAtIndex:rowIndex] scmName];
	[cell setTitle:name];
	[cell setState:[self scmIsEnabled:name] ? NSOnState : NSOffState];
}

- (id)tableView:(NSTableView*)tableView objectValueForTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex
{
	return [[delegates objectAtIndex:rowIndex] scmName];
}

- (void)tableView:(NSTableView*)tableView setObjectValue:(id)value forTableColumn:(NSTableColumn*)tableColumn row:(int)rowIndex
{
	
	[self setScm:[[delegates objectAtIndex:rowIndex] scmName] isEnabled:[value boolValue]];
	[self reloadStatusesForAllProjects:YES];
}

// ===========
// = Utility =
// ===========
- (NSString*)pathForVariable:(NSString*)shellVariableName paths:(NSArray*)paths;
{
	NSArray* prefs = [[OakPreferencesManager sharedInstance] performSelector:@selector(shellVariables)];
	for(int index = 0; index < [prefs count]; index++)
	{
		NSDictionary* pref = [prefs objectAtIndex:index];
		if([[pref objectForKey:@"variable"] isEqualToString:shellVariableName] && [[pref objectForKey:@"enabled"] boolValue])
			return [pref objectForKey:@"value"];
	}
	for(int index = 0; index < [paths count]; index++)
	{
		NSString* path = [paths objectAtIndex:index];
		if([[NSFileManager defaultManager] fileExistsAtPath:path])
			return path;
	}
	return nil;
}
@end
