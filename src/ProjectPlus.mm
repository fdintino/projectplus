#import "ProjectPlus.h"
#import "TextMate.h"

NSString* ProjectPlus_redrawRequired = @"ProjectPlus_redrawRequired";

float ToolbarHeightForWindow(NSWindow *window)
{
	NSToolbar *toolbar = [window toolbar];
	if(toolbar && [toolbar isVisible])
	{
		NSRect windowFrame = [NSWindow contentRectForFrameRect:[window frame] styleMask:[window styleMask]];
		float toolbarHeight = NSHeight(windowFrame) - NSHeight([[window contentView] frame]);
		return toolbarHeight;
	}
	else return 0.0;
}

static NSString* const PROJECTPLUS_PREFERENCES_LABEL = @"Project+";

@implementation NSWindowController (PreferenceAdditions)
- (NSArray*)ProjectPlus_toolbarAllowedItemIdentifiers:(id)sender
{
	return [[self ProjectPlus_toolbarAllowedItemIdentifiers:sender] arrayByAddingObject:PROJECTPLUS_PREFERENCES_LABEL];
}
- (NSArray*)ProjectPlus_toolbarDefaultItemIdentifiers:(id)sender
{
	return [[self ProjectPlus_toolbarDefaultItemIdentifiers:sender] arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:PROJECTPLUS_PREFERENCES_LABEL,nil]];
}
- (NSArray*)ProjectPlus_toolbarSelectableItemIdentifiers:(id)sender
{
	return [[self ProjectPlus_toolbarSelectableItemIdentifiers:sender] arrayByAddingObject:PROJECTPLUS_PREFERENCES_LABEL];
}

- (NSToolbarItem*)ProjectPlus_toolbar:(NSToolbar*)toolbar itemForItemIdentifier:(NSString*)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *item = [self ProjectPlus_toolbar:toolbar itemForItemIdentifier:itemIdentifier willBeInsertedIntoToolbar:flag];
	if([itemIdentifier isEqualToString:PROJECTPLUS_PREFERENCES_LABEL])
		[item setImage:[[ProjectPlus sharedInstance] iconImage]];
	return item;
}

- (void)ProjectPlus_selectToolbarItem:(id)item
{
	if ([[item label] isEqualToString:PROJECTPLUS_PREFERENCES_LABEL]) {
		if ([[self valueForKey:@"selectedToolbarItem"] isEqualToString:[item label]]) return;
		[[self window] setTitle:[item label]];
		[self setValue:[item label] forKey:@"selectedToolbarItem"];
		
		NSSize prefsSize = [[[ProjectPlus sharedInstance] preferencesView] frame].size;
		NSRect frame = [[self window] frame];
		prefsSize.width = [[self window] contentMinSize].width;

		[[self window] setContentView:[[ProjectPlus sharedInstance] preferencesView]];

		float newHeight = prefsSize.height + ToolbarHeightForWindow([self window]) + 22;
		frame.origin.y += frame.size.height - newHeight;
		frame.size.height = newHeight;
		frame.size.width = prefsSize.width;
		[[self window] setFrame:frame display:YES animate:YES];
	} else {
		[self ProjectPlus_selectToolbarItem:item];
	}
}
@end

@implementation NSWindowController (OakProjectController_Redrawing)
- (id)ProjectPlus_init
{
	self = [self ProjectPlus_init];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ProjectPlus_redrawRequired:) name:ProjectPlus_redrawRequired object:nil];
	
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(ProjectPlus_boundsChangeHandler:)
		name:NSOutlineViewItemDidExpandNotification
		object:nil
	];
	[[NSNotificationCenter defaultCenter]
		addObserver:self
		selector:@selector(ProjectPlus_boundsChangeHandler:)
		name:NSViewFrameDidChangeNotification
		object:nil
	];
	
	return self;
}

- (void)ProjectPlus_boundsChangeHandler:(NSNotification*)notification
{
    [self performSelectorOnMainThread:@selector(ProjectPlus_checkOutlineViewBounds)
                                  withObject:nil
                               waitUntilDone:NO];
}

- (void)ProjectPlus_checkOutlineViewBounds
{
    NSOutlineView *outlineView = (NSOutlineView*)[self valueForKey:@"outlineView"];
	
	NSRect ovb = [outlineView bounds];
	NSRect svb = [[[outlineView enclosingScrollView] contentView] bounds];
	
	if(ovb.size.width!=svb.size.width)
	{
		ovb.size.width=svb.size.width;
		
		[outlineView setBoundsSize:ovb.size];
		
		[outlineView setColumnAutoresizingStyle:NSTableViewLastColumnOnlyAutoresizingStyle];
		[outlineView sizeLastColumnToFit];
		
		[outlineView setNeedsDisplay:YES];
	}
}

- (void)ProjectPlus_redrawRequired:(NSNotification*)notification
{
	[self performSelectorOnMainThread:@selector(ProjectPlus_redisplay)
                           withObject:nil
                        waitUntilDone:NO];
}

- (void)ProjectPlus_redisplay
{
    NSOutlineView *outlineView = (NSOutlineView*)[self valueForKey:@"outlineView"];
	[outlineView setNeedsDisplay:YES];
    
}

-(void)ProjectPlus_applicationDidBecomeActiveNotification:(NSNotification *)notification {
    [self ProjectPlus_applicationDidBecomeActiveNotification:notification];
    if ([self respondsToSelector:@selector(scmRefreshApplicationDidBecomeActiveNotification)]) {
        [self performSelectorOnMainThread:@selector(scmRefreshApplicationDidBecomeActiveNotification)
                               withObject:nil
                            waitUntilDone:NO];
    }
    
	[self performSelectorOnMainThread:@selector(resortItems)
						   withObject:nil
	                    waitUntilDone:true];
    [self ProjectPlus_redrawRequired:notification];
}
@end

static ProjectPlus* SharedInstance = nil;
@implementation ProjectPlus
+ (ProjectPlus*)sharedInstance
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
		quickLookAvailable = [[NSBundle bundleWithPath:@"/System/Library/PrivateFrameworks/QuickLookUI.framework"] load];

		NSApp = [NSApplication sharedApplication];

		sparkleUpdater = [SUUpdater updaterForBundle:[NSBundle bundleForClass:[self class]]];
		[sparkleUpdater applicationDidFinishLaunching:[NSNotification notificationWithName:NSApplicationDidFinishLaunchingNotification object:NSApp]];

		// Preferences
		NSString* nibPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"Preferences" ofType:@"nib"];
		NSWindowController *controller = [[NSWindowController alloc] initWithWindowNibPath:nibPath owner:self];
		[controller showWindow:self];


		[OakPreferencesManager jr_swizzleMethod:@selector(toolbarAllowedItemIdentifiers:) withMethod:@selector(ProjectPlus_toolbarAllowedItemIdentifiers:) error:NULL];
		[OakPreferencesManager jr_swizzleMethod:@selector(toolbarDefaultItemIdentifiers:) withMethod:@selector(ProjectPlus_toolbarDefaultItemIdentifiers:) error:NULL];
		[OakPreferencesManager jr_swizzleMethod:@selector(toolbarSelectableItemIdentifiers:) withMethod:@selector(ProjectPlus_toolbarSelectableItemIdentifiers:) error:NULL];
		[OakPreferencesManager jr_swizzleMethod:@selector(toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:) withMethod:@selector(ProjectPlus_toolbar:itemForItemIdentifier:willBeInsertedIntoToolbar:) error:NULL];
		[OakPreferencesManager jr_swizzleMethod:@selector(selectToolbarItem:) withMethod:@selector(ProjectPlus_selectToolbarItem:) error:NULL];
		[OakProjectController jr_swizzleMethod:@selector(applicationDidBecomeActiveNotification:) withMethod:@selector(ProjectPlus_applicationDidBecomeActiveNotification:) error:NULL];
		[OakProjectController jr_swizzleMethod:@selector(init) withMethod:@selector(ProjectPlus_init) error:NULL];
	}

	return SharedInstance;
}

- (id)initWithPlugInController:(id <TMPlugInController>)aController
{
	if((self = [self init]))
	{
		NSString* iconPath = [[NSBundle bundleForClass:[self class]] pathForResource:@"projectplus" ofType:@"tiff"];
		icon = [[NSImage alloc] initByReferencingFile:iconPath];
	}
	return self;
}

- (void)dealloc
{
	[icon release];
	[super dealloc];
}

- (void)awakeFromNib
{
	if([[NSUserDefaults standardUserDefaults] stringForKey:@"ProjectPlus Selected Tab Identifier"])
		[preferencesTabView selectTabViewItemWithIdentifier:[[NSUserDefaults standardUserDefaults] stringForKey:@"ProjectPlus Selected Tab Identifier"]];
}

- (IBAction)showSortingDefaultsSheet:(id)sender
{
	[NSApp beginSheet:sortingDefaultsSheet modalForWindow:[preferencesTabView window] modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)orderOutShortingDefaultSheet:(id)sender
{
	[sortingDefaultsSheet orderOut:nil];
	[NSApp endSheet:sortingDefaultsSheet];
}

- (void)tabView:(NSTabView*)tabView didSelectTabViewItem:(NSTabViewItem*)tabViewItem
{
	[[NSUserDefaults standardUserDefaults] setObject:[tabViewItem identifier] forKey:@"ProjectPlus Selected Tab Identifier"];
}

- (IBAction)notifyOutlineViewsAsDirty:(id)sender;
{
	[[NSNotificationCenter defaultCenter] postNotificationName:ProjectPlus_redrawRequired object:nil];
}

- (void)watchDefaultsKey:(NSString*)keyPath
{
	[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:keyPath options:NULL context:NULL];
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)changes context:(void*)context
{
	[self notifyOutlineViewsAsDirty:self];
}

- (NSView*)preferencesView
{
	return preferencesView;
}

- (NSImage*)iconImage;
{
	return icon;
}

- (BOOL)quickLookAvailable
{
	return quickLookAvailable;
}
@end
