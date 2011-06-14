//
//  MHOutlineView.m
//  ProjectPlus
//
//  Created by Mark Huot on 6/6/11.
//  Copyright 2011 Home. All rights reserved.
//

#import "MHOutlineView.h"


@implementation MHOutlineView

- (id)init
{
    self = [super init];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (NSRect)frameOfCellAtColumn:(NSInteger)column row:(NSInteger)row
{
    NSRect rc = [super frameOfCellAtColumn:column row:row];
    
    if (row > 0)
    {
        CGFloat indent = 14.0; //[self indentationPerLevel];
        rc.origin.x += indent;
        rc.size.width -= indent;
    }
    
    return rc;
}

- (void)dealloc
{
    [super dealloc];
}

@end