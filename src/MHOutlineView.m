//
//  MHOutlineView.m
//  ProjectPlus
//
//  Created by Mark Huot on 6/6/11.
//  Copyright 2011 Home. All rights reserved.
//

#import "MHOutlineView.h"


@implementation MHOutlineView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    return self;
}

- (void)awakeFromNib
{
    NSLog(@"%@", [self window]);
    [[self window] setAcceptsMouseMovedEvents:YES];
    trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
    mouseOverView = NO;
    mouseOverRow = -1;
    lastOverRow = -1;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row
{
    NSRect rc = [super frameOfCellAtColumn:column row:row];

    if (row > 0) {
        CGFloat indent = 14.0; //[self indentationPerLevel];
        rc.origin.x += indent;
        rc.size.width -= indent;
    }

    return rc;
}

- (void)mouseEntered:(NSEvent*)theEvent
{
    NSLog(@"entered.");
    mouseOverView = YES;
}

- (void)mouseMoved:(NSEvent*)theEvent
{
    id myDelegate = [self delegate];

    if (!myDelegate) {
        return; // No delegate, no need to track the mouse.
    }
    if (![myDelegate respondsToSelector:@selector(tableView:willDisplayCell:forTableColumn:row:)]) {
        return; // If the delegate doesn't modify the drawing, don't track.
    }

    if (mouseOverView) {
        mouseOverRow = [self rowAtPoint:[self convertPoint:[theEvent locationInWindow] fromView:nil]];

        if (lastOverRow == mouseOverRow) {
            return;
        } else {
            [self setNeedsDisplayInRect:[self rectOfRow:lastOverRow]];
            lastOverRow = mouseOverRow;
        }

        [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    }
}

- (void)mouseExited:(NSEvent *)theEvent
{
    NSLog(@"exited.");
    mouseOverView = NO;
    [self setNeedsDisplayInRect:[self rectOfRow:mouseOverRow]];
    mouseOverRow = -1;
    lastOverRow = -1;
}

- (int)mouseOverRow
{
    return mouseOverRow;
}

- (void)viewDidEndLiveResize
{
    [super viewDidEndLiveResize];

    [self removeTrackingRect:trackingTag];
    trackingTag = [self addTrackingRect:[self frame] owner:self userData:nil assumeInside:NO];
}

- (void)dealloc
{
    [self removeTrackingRect:trackingTag];
    [super dealloc];
}

@end
