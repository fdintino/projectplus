#import "TextMate.h"
#import "Sorting.h"

NSInteger sort_items(id a, id b, void *context)
{
	item_sort_descriptor *sortDescriptor = (item_sort_descriptor*)context;
	NSString *aText = [a objectForKey:@"displayName"];
	NSString *bText = [b objectForKey:@"displayName"];
	BOOL ignoreExtensions = NO;

	if(sortDescriptor->folders_on_top)
	{
		BOOL aIsDir = [a objectForKey:@"children"] != nil;
		BOOL bIsDir = [b objectForKey:@"children"] != nil;
		
		if(aIsDir && bIsDir)
			ignoreExtensions = YES; // Fall through to name sorting but ignore extensions
		else if(aIsDir)
			return NSOrderedAscending;
		else if(bIsDir)
			return NSOrderedDescending;
	}
	
	if(sortDescriptor->by_extension && ! ignoreExtensions)
	{
		aText = [aText pathExtension];
		bText = [bText pathExtension];
	}
	
	int result = [aText caseInsensitiveCompare:bText];
	if (not sortDescriptor->ascending)
		result = -result;
	return result;
}


@implementation NSMutableArray (RecursiveSort)
- (void)recursiveSortOutlineView:(NSOutlineView*)outlineView
                       ascending:(BOOL)ascending
                     byExtension:(BOOL)byExtension
                    foldersOnTop:(BOOL)foldersOnTop
{
	struct item_sort_descriptor sortDescriptor;
	sortDescriptor.ascending      = ascending;
	sortDescriptor.by_extension   = byExtension;
	sortDescriptor.folders_on_top = foldersOnTop;
	
	unsigned int itemCount = [self count];

	for(unsigned int index = 0; index < itemCount; index += 1)
	{
		id item = [self objectAtIndex:index];
		NSMutableArray *children = [item objectForKey:@"children"];
		if (children != nil && [outlineView isItemExpanded:item]) {
			[children recursiveSortOutlineView:outlineView
			                         ascending:ascending
			                       byExtension:byExtension
			                      foldersOnTop:foldersOnTop];
		}
	}

	[self sortUsingFunction:sort_items context:&sortDescriptor];
}
@end

@implementation NSWindowController (OakProjectController_Sorting)
- (NSMutableDictionary*)sortDescriptor
{
	return [ProjectPlusSorting sortDescriptorForProjectController:self];
}

- (void)resortItems:(NSMutableArray*)items maintainItemSelection:(BOOL)maintainSelection
{
	NSOutlineView *outlineView = [self valueForKey:@"outlineView"];
	NSMutableDictionary *sortDescriptor = [self sortDescriptor];

    // In the case of adding and removing files, the selection in the outline
    // view remains where the file originally appeared before sorting, so we
    // need to track the currently selected item and set it back after sorting
    // is complete.
    NSArray *selectedItems;
    NSUInteger selectedItemsCount;
    if (maintainSelection) {
        selectedItems = [outlineView performSelector:@selector(selectedItems)];
        selectedItemsCount = [selectedItems count];        
    }

	[items recursiveSortOutlineView:outlineView
	                      ascending:![[sortDescriptor objectForKey:@"descending"] boolValue]
	                    byExtension: [[sortDescriptor objectForKey:@"byExtension"] boolValue]
	                   foldersOnTop: [[sortDescriptor objectForKey:@"foldersOnTop"] boolValue]];

	[outlineView performSelectorOnMainThread:@selector(reloadData)
	                              withObject:nil
	                           waitUntilDone:true];

    // Re-select the originally selected item
    if (maintainSelection && selectedItemsCount > 0) {
        [outlineView performSelector:@selector(selectItems:)
                          withObject:selectedItems
                          afterDelay:0.0];
    }
}

- (void)resortItems
{
    NSMutableArray *rootItems = [self valueForKey:@"rootItems"];
    [self resortItems:rootItems maintainItemSelection:NO];
}

- (void)ProjectPlus_Sorting_windowDidLoad
{
	[self ProjectPlus_Sorting_windowDidLoad];
	
	if(not [ProjectPlusSorting useSorting])
		return;

	[ProjectPlusSorting addProjectController:self];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[ProjectPlusSorting foldersOnTop]] forKey:@"foldersOnTop"];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[ProjectPlusSorting byExtension]] forKey:@"byExtension"];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[ProjectPlusSorting descending]] forKey:@"descending"];
	[self resortItems];
}

- (void)toggleDescending: (NSMenuItem *) menuItem
{
	[menuItem setState: ![menuItem state] ? NSOnState : NSOffState];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[menuItem state]] forKey:@"descending"];
	[self resortItems];
}

- (void)toggleByExtension: (NSMenuItem *) menuItem
{
	[menuItem setState: ![menuItem state] ? NSOnState : NSOffState];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[menuItem state]] forKey:@"byExtension"];
	[self resortItems];
}

- (void)toggleFoldersOnTop: (NSMenuItem *) menuItem
{
	[menuItem setState: ![menuItem state] ? NSOnState : NSOffState];
	[[self sortDescriptor] setObject:[NSNumber numberWithBool:[menuItem state]] forKey:@"foldersOnTop"];
	[self resortItems];
}

- (void)ProjectPlus_Sorting_insertItems:(NSArray*)itemsToInsert before:(NSDictionary*)beforeItem
{
    [self ProjectPlus_Sorting_insertItems:itemsToInsert before:beforeItem];

    if ([itemsToInsert count] == 1) {
        NSDictionary *item = [itemsToInsert objectAtIndex:0];
        // If the item has the key children, then a folder has been inserted. In that case
        // we can't select the item because it will unfocus the file rename view. We
        // also don't need to, because the NSOutlineViewItemDidExpandNotification will get
        // posted after the folder is created (the NSOutlineView auto expands new folders).
        if ([item valueForKey:@"children"] != nil) {
            return;
        }
    }

    [self resortItems];

    NSOutlineView *outlineView = [self valueForKey:@"outlineView"];
    [outlineView performSelector:@selector(selectItems:)
                      withObject:itemsToInsert
                      afterDelay:0.0];
}


- (BOOL)ProjectPlus_Sorting_outlineView:(NSOutlineView*)outlineView
                     acceptDrop:(id <NSDraggingInfo>)sender
                           item:(NSDictionary*)dropItem
                     childIndex:(int)index
{
    BOOL dropAllowed = [self ProjectPlus_Sorting_outlineView:outlineView
                                          acceptDrop:sender
                                                item:dropItem
                                          childIndex:index];
    if (dropAllowed == YES) {
        [self resortItems];
    }
    return dropAllowed;
}

- (void)ProjectPlus_Sorting_outlineView:(NSOutlineView*)view
                         setObjectValue:(NSString*)objectValue
                         forTableColumn:(NSTableColumn*)tableColumn
                                 byItem:(NSDictionary*)item
{
	[self ProjectPlus_Sorting_outlineView:view
						   setObjectValue:objectValue
						   forTableColumn:tableColumn
								   byItem:item];
    NSMutableArray *rootItems = [self valueForKey:@"rootItems"];
    [self resortItems:rootItems maintainItemSelection:YES];     
}

- (void)ProjectPlus_Sorting_removeProjectFilesWarningDidEnd:(NSAlert*)alert
                                                 returnCode:(int)returnCode
                                                contextInfo:(void *)context
{
    [self ProjectPlus_Sorting_removeProjectFilesWarningDidEnd:alert
                                                   returnCode:returnCode
                                                  contextInfo:context];
    if (returnCode == 1000) {
        NSMutableArray *rootItems = [self valueForKey:@"rootItems"];
        [self resortItems:rootItems maintainItemSelection:YES];        
    }
}
@end


// Hook into the NSOutlineViewItemDidExpandNotification notification
// Needed because we now only sort NSOutlineView items which are not collapsed

@implementation NSOutlineView (ProjectPlusOutlineView)

-(id)ProjectPlus_Sorting_initWithCoder:(NSCoder*)coder
{
	id initOutlineView = [self ProjectPlus_Sorting_initWithCoder:coder];
	NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];

	[nc addObserver:self
	       selector:@selector(ProjectPlus_Sorting_outlineViewItemDidExpand:)
	           name:NSOutlineViewItemDidExpandNotification
	         object:(id)self];

	return initOutlineView;
}

- (void)ProjectPlus_Sorting_outlineViewItemDidExpand:(NSNotification *)notification
{
	id item = [[notification userInfo] objectForKey:@"NSObject"];

	BOOL ascending, byExtension, foldersOnTop;
	
	id delegate = [self delegate];
	if ([delegate isKindOfClass:[NSWindowController class]]) {
		NSMutableDictionary *sortDescriptor = [delegate sortDescriptor];
		ascending    = ![[sortDescriptor objectForKey:@"descending"] boolValue];
		byExtension  =  [[sortDescriptor objectForKey:@"byExtension"] boolValue];
		foldersOnTop =  [[sortDescriptor objectForKey:@"foldersOnTop"] boolValue];
	} else {
		NSLog(@"Expected NSOutlineView delegate to be NSWindowController, instead got %@", [delegate className]);
        return;
	}

	NSMutableArray *children = [item objectForKey:@"children"];

    if ([children count] > 0) {
        NSArray *selectedItems = [self performSelector:@selector(selectedItems)];
        NSUInteger selectedItemsCount = [selectedItems count];
        
        [children recursiveSortOutlineView:self
                                 ascending:ascending
                               byExtension:byExtension
                              foldersOnTop:foldersOnTop];

        if (selectedItemsCount > 0) {
            [self performSelector:@selector(selectItems:)
                              withObject:selectedItems
                              afterDelay:0.0];
        } else {
            [self performSelector:@selector(selectItem:)
                     withObject:item
                     afterDelay:0.0];
            
        }
    }
}
@end

@implementation NSButton (OakMenuButton_ProjectPlus_Sorting)
- (void)ProjectPlus_Sorting_awakeFromNib
{
	[self ProjectPlus_Sorting_awakeFromNib];

	if(not [[self window] isKindOfClass:NSClassFromString(@"NSDrawerWindow")])
		return;
	
	NSMenu *menu = (NSMenu*)[self valueForKey:@"actionMenu"];
	[menu addItem:[NSMenuItem separatorItem]];

	NSMenuItem *sortingMenu = [[NSMenuItem alloc] initWithTitle:@"Sort" action:nil keyEquivalent:@""];
	{
		NSMenu *sortingSubMenu = [[NSMenu alloc] init];
		NSMenuItem *item;
		
		item = [[NSMenuItem alloc] initWithTitle:@"Descending"
                                        action:@selector(toggleDescending:)
                                 keyEquivalent:@""];
		[item setTarget:[self valueForKey:@"delegate"]];
		[item setState:[ProjectPlusSorting descending]];
		[sortingSubMenu addItem:item];
		[item release];

		item = [[NSMenuItem alloc] initWithTitle:@"By Extension"
                                        action:@selector(toggleByExtension:)
                                 keyEquivalent:@""];
		[item setTarget:[self valueForKey:@"delegate"]];
		[item setState:[ProjectPlusSorting byExtension]];
		[sortingSubMenu addItem:item];
		[item release];

		item = [[NSMenuItem alloc] initWithTitle:@"Folders on Top"
                                        action:@selector(toggleFoldersOnTop:)
                                 keyEquivalent:@""];
		[item setTarget:[self valueForKey:@"delegate"]];
		[item setState:[ProjectPlusSorting foldersOnTop]];
		[sortingSubMenu addItem:item];
		[item release];

		[sortingMenu setSubmenu:sortingSubMenu];
		[sortingSubMenu release];
	}
	[menu addItem:sortingMenu];
	[sortingMenu release];
}

@end

static NSMutableArray* sortDescriptors = [[NSMutableArray alloc] initWithCapacity:1];

@implementation ProjectPlusSorting
+ (void)load
{
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:@"ProjectPlus Use Sorting"]];

	[OakProjectController jr_swizzleMethod:@selector(windowDidLoad)
                                withMethod:@selector(ProjectPlus_Sorting_windowDidLoad)
                                     error:NULL];

	[OakOutlineView jr_swizzleMethod:@selector(initWithCoder:)
						  withMethod:@selector(ProjectPlus_Sorting_initWithCoder:)
							   error:NULL];

	[OakProjectController jr_swizzleMethod:@selector(outlineView:setObjectValue:forTableColumn:byItem:)                                                                
								withMethod:@selector(ProjectPlus_Sorting_outlineView:setObjectValue:forTableColumn:byItem:)
									 error:NULL];
    
    [OakProjectController jr_swizzleMethod:@selector(removeProjectFilesWarningDidEnd:returnCode:contextInfo:)
                                withMethod:@selector(ProjectPlus_Sorting_removeProjectFilesWarningDidEnd:returnCode:contextInfo:)
                                     error:NULL];

    [OakProjectController jr_swizzleMethod:@selector(insertItems:before:)
                                withMethod:@selector(ProjectPlus_Sorting_insertItems:before:)
                                     error:NULL];


    [OakProjectController jr_swizzleMethod:@selector(outlineView:acceptDrop:item:childIndex:)
                                withMethod:@selector(ProjectPlus_Sorting_outlineView:acceptDrop:item:childIndex:)
                                     error:NULL];

	[OakMenuButton jr_swizzleMethod:@selector(awakeFromNib) withMethod:@selector(ProjectPlus_Sorting_awakeFromNib) error:NULL];
}

+ (BOOL)foldersOnTop
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlusSortingFoldersOnTop"];
}

+ (BOOL)byExtension
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlusSortingByExtension"];
}

+ (BOOL)descending
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlusSortingDescending"];
}

+ (BOOL)useSorting
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"ProjectPlus Use Sorting"];
}

+ (void)addProjectController:(id)projectController;
{
	NSMutableDictionary* sortDescriptor = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:NO],@"descending",
																								 [NSNumber numberWithBool:NO],@"byExtension",
																								[NSNumber numberWithBool:NO],@"foldersOnTop",
																								 nil];
	[sortDescriptors addObject:[NSDictionary dictionaryWithObjectsAndKeys:projectController,@"controller",sortDescriptor,@"sortDescriptor",nil]];
}

+ (void)removeProjectController:(id)projectController;
{
	unsigned int	controllerCount = [sortDescriptors count];

	for(unsigned int index = 0; index < controllerCount; index += 1)
	{
		NSDictionary* info = [sortDescriptors objectAtIndex:index];
		if([info objectForKey:@"controller"] == projectController)
		{
			[sortDescriptors removeObject:info];
			return;
		}
	}
}

+ (NSMutableDictionary*)sortDescriptorForProjectController:(id)projectController;
{
	unsigned int controllerCount = [sortDescriptors count];

	for(unsigned int index = 0; index < controllerCount; index += 1)
	{
		NSDictionary* info = [sortDescriptors objectAtIndex:index];
		if([info objectForKey:@"controller"] == projectController)
			return [info objectForKey:@"sortDescriptor"];
	}

	return nil;
}
@end
