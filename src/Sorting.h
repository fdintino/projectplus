#import <Foundation/Foundation.h>

struct item_sort_descriptor
{
	BOOL ascending;
	BOOL by_extension;
	BOOL folders_on_top;
};

@interface ProjectPlusSorting : NSObject
{
}
+ (BOOL)useSorting;
+ (BOOL)descending;
+ (BOOL)byExtension;
+ (BOOL)foldersOnTop;

+ (void)addProjectController:(id)projectController;
+ (void)removeProjectController:(id)projectController;
+ (NSMutableDictionary*)sortDescriptorForProjectController:(id)projectController;
@end

@interface NSMutableArray (RecursiveSort)
- (void)recursiveSortOutlineView:(NSOutlineView*)outlineView
					    ascending:(BOOL)ascending
                        byExtension:(BOOL)byExtension
                       foldersOnTop:(BOOL)foldersOnTop;
@end


@interface NSOutlineView (ProjectPlusOutlineView)
- (id)ProjectPlus_Sorting_initWithCoder:(NSCoder*)coder;
- (void)ProjectPlus_Sorting_outlineViewItemDidExpand:(NSNotification *)notification;
@end