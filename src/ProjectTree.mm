#import "JRSwizzle.h"
#import "MHOpenFiles.h"
#import "MHDividerView.h"
#import "MHOutlineView.h"
#define OakImageAndTextCell      NSClassFromString(@"OakImageAndTextCell")

@interface ProjectTree : NSObject
+ (BOOL)preserveTreeState;
+ (BOOL)useWorkspace;
@end

@implementation NSWindowController (OakProjectController)
- (void)expandItems:(NSArray*)items inOutlineView:(NSOutlineView*)outlineView toState:(NSDictionary*)treeState
{
	unsigned int itemCount = [items count];

	for(unsigned int index = 0; index < itemCount; index += 1)
	{
		NSDictionary *item = [items objectAtIndex:index];

		if(not [item objectForKey:@"children"])
			continue; // We are only interested in directories

		if(NSDictionary *treeItem = [treeState objectForKey:[item objectForKey:@"displayName"]])
		{
			if([[treeItem objectForKey:@"isExpanded"] boolValue])
				[outlineView expandItem:item];
			
			if([[treeItem objectForKey:@"subItems"] count])
				[self expandItems:[item objectForKey:@"children"] inOutlineView:outlineView toState:[treeItem objectForKey:@"subItems"]];
		}
	}
}

- (void)Document_windowDidLoad
{
    [self Document_windowDidLoad];
    
#if MAC_OS_X_VERSION_MIN_REQUIRED == MAC_OS_X_VERSION_10_7
    NSWindow *window = [self window];
    [window setCollectionBehavior:([window collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary)];
#endif
}

- (void)ProjectTree_windowDidLoad
{
    [self ProjectTree_windowDidLoad];

	if(not [ProjectTree preserveTreeState])
		return;
    
#if MAC_OS_X_VERSION_MIN_REQUIRED == MAC_OS_X_VERSION_10_7
    NSWindow *window = [self window];
    [window setCollectionBehavior:([window collectionBehavior] | NSWindowCollectionBehaviorFullScreenPrimary)];
#endif
    
    NSArray *rootItems         = [self valueForKey:@"rootItems"];
    
    /*NSDictionary *newRoot = [NSDictionary dictionaryWithObjectsAndKeys:
                             @"Files", @"displayName",
                             rootItems, @"children",
                             @"18931726348912", @"lastModified",
                             @"/", @"sourceDirectory",
                             @".", @"regexFolderFilter",
                             nil];
    NSMutableArray *newRootItems = [NSMutableArray arrayWithObject:newRoot];
    
    [self setValue:newRootItems forKey:@"rootItems"];
    
	[[self valueForKey:@"outlineView"] reloadData];*/

	NSDictionary *treeState = [[NSDictionary dictionaryWithContentsOfFile:[self valueForKey:@"filename"]] objectForKey:@"treeState"];
	if(treeState)
	{
		NSOutlineView *outlineView = [self valueForKey:@"outlineView"];
		[self expandItems:rootItems inOutlineView:outlineView toState:treeState];
	}
    
    // Update File Browser
    // 
    // First we need to grab the existing file browser outline view and update its styling
    // to bring it into this century.
    NSOutlineView *fileBrowserOutlineView = [self valueForKey:@"outlineView"];
    [fileBrowserOutlineView setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
    [fileBrowserOutlineView setRowHeight:15];
	[fileBrowserOutlineView setIntercellSpacing:NSMakeSize(3.0, 2.0)];
    [fileBrowserOutlineView setAutoresizingMask:NSViewHeightSizable];
    
    // Update the Scroll View
    // 
    // The file browser is inside an acient scroll view with a pre-aqua border, grab the
    // scroll view by looking up the view hierarchy so we can axe the border
    NSScrollView *fileBrowserScrollView = (NSScrollView *)[[fileBrowserOutlineView superview] superview];
 	[fileBrowserScrollView setBorderType: NSNoBorder];
    
    // Get the Drawer
    // 
    // A lot of our dimensions and sizing come from the "drawer" that's no longer a drawer
    // so localize a variable so we can refer to the drawer a bit more easily
    NSView *drawer = [fileBrowserScrollView superview];
    
    // Fill the Space
    // 
    // Update the scrollview to take up the entire drawer by default. As files are opened
    // this will change and it will get shorter to allow room for the workspace, but by
    // default the file browser takes up all the space and the open files outline has no
    // height at all.
    [fileBrowserScrollView setFrame:NSMakeRect(0, 0, [drawer frame].size.width, [drawer frame].size.height)];
    
    // if we're using the workspace approach, not tabs
    if ([ProjectTree useWorkspace])
    {
        // Create the Open Files View
        //
        // No IB for plugins so a lot of code here to programatically create a scroll view to
        // contain the open files view
        NSRect          scrollFrame = NSMakeRect(0.0, [drawer frame].size.height, [drawer frame].size.width, 0.0);
        NSScrollView*   newScrollView  = [[[NSScrollView alloc] initWithFrame:scrollFrame] autorelease];
        [newScrollView setVerticalScroller:NO];
        [newScrollView setHorizontalScroller:NO];
        [newScrollView setBorderType:NSNoBorder];
        [newScrollView setAutohidesScrollers:YES];
        [newScrollView setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
        
        NSRect          clipViewBounds  = [[newScrollView contentView] bounds];
        MHOutlineView    *openFiles     = [[[MHOutlineView alloc] initWithFrame:clipViewBounds] autorelease];
        [openFiles setSelectionHighlightStyle:NSTableViewSelectionHighlightStyleSourceList];
        [openFiles setRowHeight:14];
        [openFiles setIntercellSpacing:NSMakeSize(3.0, 6.0)];
        [openFiles setHeaderView:nil];
        [openFiles setFocusRingType:NSFocusRingTypeNone];
        [openFiles setAutoresizingMask:NSViewWidthSizable];
        
        id cell = [[OakImageAndTextCell alloc] init];
        [cell setFont:[NSFont fontWithName:@"Lucida Grande" size:11.0]];
        
        NSTableColumn*  firstColumn     = [[[NSTableColumn alloc] initWithIdentifier:@"firstColumn"] autorelease];
        [[firstColumn headerCell] setStringValue:@"First Column"];
        [firstColumn setResizingMask:NSTableColumnAutoresizingMask];
        [firstColumn setWidth:[drawer frame].size.width];
        [firstColumn setDataCell:cell];
        [openFiles addTableColumn:firstColumn];
        [openFiles setOutlineTableColumn:firstColumn];
        
        MHOpenFiles *openFilesClass = [MHOpenFiles objectForTabs:[self valueForKey:@"tabBarView"]];
        [openFiles setDataSource:openFilesClass];
        [openFiles setDelegate:openFilesClass];
        [openFilesClass setOutlineView:openFiles];
        [openFilesClass setFileBrowserView:[self valueForKey:@"outlineView"]];
        [openFilesClass setEditorView:[self valueForKey:@"textView"]];
        
        [newScrollView setDocumentView:openFiles];
        [drawer addSubview:newScrollView];
        
        // Add the divider
        //
        // 
        NSView *dividerView = [[MHDividerView alloc] initWithFrame:NSMakeRect(0, [drawer frame].size.height+2, [drawer frame].size.width, 2.0)];
        [dividerView setAutoresizingMask:NSViewWidthSizable|NSViewMinYMargin];
        [drawer addSubview:dividerView];
    
        // Let our class know where the divider is so it can be moved around as the
        // open file list changes
        [openFilesClass setDividerView:dividerView];
    }
    
    // eventually remove the ugly buttons, for now they just get covered by the scroll view though
    // NSArray *subviews = [[scrollView superview] subviews];
}

- (NSDictionary*)outlineView:(NSOutlineView*)outlineView stateForItems:(NSArray*)items
{
	NSMutableDictionary *treeState = [NSMutableDictionary dictionaryWithCapacity:3];
	unsigned int itemCount = [items count];

	for(unsigned int index = 0; index < itemCount; index += 1)
	{
		NSDictionary *item = [items objectAtIndex:index];
		if([outlineView isItemExpanded:item])
		{
			NSDictionary *subTreeState = [self outlineView:outlineView stateForItems:[item objectForKey:@"children"]];
			[treeState setObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES],@"isExpanded",
																								 subTreeState,@"subItems",
																								 nil] forKey:[item objectForKey:@"displayName"]];
		}
	}	
	
	return treeState;
}

- (BOOL)ProjectTree_writeToFile:(NSString*)fileName
{
	BOOL result = [self ProjectTree_writeToFile:fileName];
	if(result && [ProjectTree preserveTreeState])
	{
		NSMutableDictionary *project = [NSMutableDictionary dictionaryWithContentsOfFile:fileName];
		NSDictionary *treeState      = [self outlineView:[self valueForKey:@"outlineView"] stateForItems:[self valueForKey:@"rootItems"]];
		[project setObject:treeState forKey:@"treeState"];
		result = [project writeToFile:fileName atomically:NO];
	}
	return result;
}

- (void)ProjectTree_outlineView:(id)outlineView willDisplayCell:(id)cell forTableColumn:(id)column item:(NSDictionary *)item
{
    NSString *path = [item objectForKey:@"filename"];
    if (!path)
    {
        path = [item objectForKey:@"sourceDirectory"];
    }
    
    if ([[item objectForKey:@"displayName"] isEqualTo:@"Files"])
    {
        [cell setImage:nil];
        return;
    }
    
    NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:path];
    [icon setSize:NSMakeSize(16.0, 16.0)];
    [cell setImage:icon];
}

- (void)ProjectTree_tabBarView:(id)arg1 didOpenTab:(id)tab
{
    [self ProjectTree_tabBarView:arg1 didOpenTab:tab];
    
    MHOpenFiles *openFilesClass = [MHOpenFiles objectForTabs:[self valueForKey:@"tabBarView"]];
    [openFilesClass addFile:[tab identifier]];
}
- (void)ProjectTree_tabBarView:(id)arg1 didCloseTab:(id)tab
{
	[self ProjectTree_tabBarView:arg1 didOpenTab:tab];
    
    MHOpenFiles *openFilesClass = [MHOpenFiles objectForTabs:[self valueForKey:@"tabBarView"]];
    [openFilesClass removeFile:[tab identifier]];
}

- (void)ProjectTree_tabBarView:(id)arg1 didSelectTab:(id)tab
{
	[self ProjectTree_tabBarView:arg1 didSelectTab:tab];
	
	MHOpenFiles *openFilesClass = [MHOpenFiles objectForTabs:[self valueForKey:@"tabBarView"]];
	[openFilesClass selectFile:[tab identifier]];
}


@end

@implementation ProjectTree
+ (void)load
{
	[[NSUserDefaults standardUserDefaults]
     registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
                       [NSNumber numberWithBool:YES], @"ProjectPlus Preserve Tree",
                       [NSNumber numberWithBool:YES], @"ProjectPlus Workspace",
                       nil]];
    
    [NSClassFromString(@"OakDocumentController") jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(Document_windowDidLoad) error:NULL];
    
	[NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(windowDidLoad) withMethod:@selector(ProjectTree_windowDidLoad) error:NULL];
	[NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(writeToFile:) withMethod:@selector(ProjectTree_writeToFile:) error:NULL];
    [NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(outlineView:willDisplayCell:forTableColumn:item:) withMethod:@selector(ProjectTree_outlineView:willDisplayCell:forTableColumn:item:) error:NULL];
    
    // toggle workspace vs. tabs
    if ([ProjectTree useWorkspace])
    {
        //[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"OakProjectWindowShowTabBarEnabled"];
        //[[NSUserDefaults standardUserDefaults] synchronize];
        
        [NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(tabBarView:didOpenTab:) withMethod:@selector(ProjectTree_tabBarView:didOpenTab:) error:NULL];
        [NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(tabBarView:didCloseTab:) withMethod:@selector(ProjectTree_tabBarView:didCloseTab:) error:NULL];
        [NSClassFromString(@"OakProjectController") jr_swizzleMethod:@selector(tabBarView:didSelectTab:) withMethod:@selector(ProjectTree_tabBarView:didSelectTab:) error:NULL];
    }
    
    else
    {
        //[[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"OakProjectWindowShowTabBarEnabled"];
        //[[NSUserDefaults standardUserDefaults] synchronize];
    }
}

+ (BOOL)preserveTreeState;
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Preserve Tree"];
}

+ (BOOL)useWorkspace;
{
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Workspace"];
}
@end
