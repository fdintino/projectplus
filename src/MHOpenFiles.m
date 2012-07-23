//
//  MHOpenFiles.m
//  ProjectPlus
//
//  Created by Mark Huot on 5/13/11.
//  Copyright 2011 Home. All rights reserved.
//

#import "MHOutlineView.h"
#import "MHOpenFiles.h"

@implementation MHOpenFiles

static NSMutableArray *objectList = NULL;

+ (id)objectForTabs:(id)theTabs
{
    if (!objectList) {
        objectList = [[NSMutableArray alloc] initWithCapacity:1];
    }

    MHOpenFiles *item;
    for (item in objectList) {
        if ([[item tabView] isEqualTo:theTabs]) {
            return item;
        }
    }

    MHOpenFiles *obj = [[MHOpenFiles alloc] initForTabs:theTabs];
    [objectList addObject:obj];

    return obj;
}

- (id)initForTabs:(id)theTabs
{
    self = [super init];
    if (self) {
        tabView = theTabs;
        openFiles = [[NSMutableArray alloc] initWithCapacity:1];
    }

    return self;
}

#define MyPrivateTableViewDataType @"MyPrivateTableViewDataType"

- (void)setOutlineView:(NSOutlineView *)theOutlineView
{
    outlineView = theOutlineView;

#if defined(MAC_OS_X_VERSION_10_7)
    [outlineView setIndentationPerLevel:0.0];
#endif

    [outlineView registerForDraggedTypes: [NSArray arrayWithObject:MyPrivateTableViewDataType]];
    [outlineView expandItem:[outlineView itemAtRow:0]];
}

- (void)setFileBrowserView:(NSOutlineView *)theFileBrowserView
{
    fileBrowserView = theFileBrowserView;
}

- (void)setDividerView:(NSView *)theDividerView
{
    dividerView = theDividerView;
}

- (void)setEditorView:(NSTextView *)theEditorView
{
    editorView = theEditorView;
}

- (id)tabView
{
    return tabView;
}

- (void)setTabView:(id)theTabView
{
    tabView = theTabView;
}

- (void)addFile:(NSString *)path
{
    [tabView setFrame:NSMakeRect(0, -1000, 100, 100)];

    [openFiles addObject:path];
    [outlineView reloadData];
    [self resizeViews];
}

- (void)removeFile:(NSString *)path
{
    selectedItem = [outlineView itemAtRow:[outlineView selectedRow]];

    [openFiles removeObject:path];
    [outlineView reloadData];

    [self selectFile:selectedItem];

    [self resizeViews];
}

- (void)selectFile:(NSString *)path
{
    int len = [outlineView numberOfRows];
    int i;
    for (i = 0; i<len; i++) {
        id rowPath = [outlineView itemAtRow:i];
        if ([path isEqualToString:rowPath]) {
            [outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
        }
    }
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
    return (item == nil) ? 1 : [openFiles count];
}


- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
    return (item == @"WORKSPACE") ? YES : NO;
}


- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {

    return (item == nil) ? @"WORKSPACE" : [openFiles objectAtIndex:index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isGroupItem:(id)item
{
    return (item == @"WORKSPACE") ? YES : NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
    return (item == @"WORKSPACE") ? NO : YES;
}


- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
    NSURL *url = [NSURL fileURLWithPath:item];
    return [url lastPathComponent];
}

- (void)outlineView:(MHOutlineView *)theOutlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{

    //NSInteger rowIndex = [theOutlineView rowForItem:item];

    //if ([theOutlineView mouseOverRow] == rowIndex) {
    //    NSLog(@"%d could be highlighted", rowIndex);
    //} else {
    //    NSLog(@"%d shouldn't be highlighted", rowIndex);
    //}

    if (item == @"WORKSPACE") {
        [cell setImage:nil];
    } else {
        NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFile:item];
        [icon setSize:NSMakeSize(16.0, 16.0)];
        [cell setImage:icon];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
    // if we actually deselected everything by clicking outside the list then
    // stop right here.
    if ([outlineView selectedRow] == -1) {
        return;
    }

    // get object
    id item = [outlineView itemAtRow:[outlineView selectedRow]];
    [tabView performSelector:@selector(selectTabWithIdentifier:) withObject:item];

    // deselect the file broswer
    [fileBrowserView deselectAll:self];
}

- (BOOL)outlineView:(NSOutlineView *)ov writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard
{
    for (id item in items) {
        if ([item isEqualToString:@"WORKSPACE"]) {
            continue;
        }

        draggedIndex = [ov rowForItem:item]-1;
        selectedItem = [ov itemAtRow:[ov selectedRow]];
    }

    //NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    [pasteboard declareTypes:[NSArray arrayWithObject:MyPrivateTableViewDataType] owner:self];
    //[pboard setData:data forType:MyPrivateTableViewDataType];
    return YES;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView validateDrop:(id<NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)index
{
    if (([item isEqualToString:@"WORKSPACE"] && index >= 0) || (item == nil && index == 1)) {
        return NSDragOperationMove;
    }

    return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id<NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)index
{
    if (item == nil && index == 1) {
        index = [openFiles count];
    }

    id object = [openFiles objectAtIndex:draggedIndex];

    [openFiles removeObjectAtIndex:draggedIndex];

    if (draggedIndex < index) {
        index--;
    }

    [openFiles insertObject:object atIndex:index];


    [ov reloadData];

    [self selectFile:selectedItem];

    return YES;
}

- (void)resizeViews
{
    float neededHeight = ([outlineView numberOfRows] * [outlineView rowHeight]) + (6.0 * [outlineView numberOfRows]) + 2.0;

    NSView *openFilesCustomView = (NSView *)[[outlineView superview] superview];

    NSView *drawerView = [openFilesCustomView superview];
    float y = [drawerView frame].size.height - neededHeight;
    float w = [openFilesCustomView frame].size.width;

    [[openFilesCustomView animator] setFrame:NSMakeRect(0.0, y, w, neededHeight)];

    [[[[fileBrowserView superview] superview] animator] setFrame:NSMakeRect(0, 0, w, [drawerView frame].size.height - neededHeight - 2.0)];

    [[dividerView animator] setFrameOrigin:NSMakePoint(0, [drawerView frame].size.height - neededHeight - 2.0)];
}

- (void)dealloc
{
    [super dealloc];
}

@end