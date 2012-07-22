//
//  MHOutlineView.h
//  ProjectPlus
//
//  Created by Mark Huot on 6/6/11.
//  Copyright 2011 Home. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface MHOutlineView : NSOutlineView {
    NSTrackingRectTag trackingTag;
    BOOL mouseOverView;
    int mouseOverRow;
    int lastOverRow;
}

@end
