//
//  LTTextPageView.m
//  LTCoreText
//
//  Created by ito on H.23/07/07.
//  Copyright 平成23年 __MyCompanyName__. All rights reserved.
//

#import "LTTextPageView.h"
#import "DTTextAttachment.h"
#import "LTImageDownloader.h"
#import "LTTextImageView.h"
#import "LTTextImageScrollView.h"

#import "LTDummyObject.h"

@interface LTTextPageView()
{
	LTTextLayouter* _layouter;
	NSUInteger _index;
	BOOL _isNeedShowAttachments;
	NSMutableArray* _imageSizes[2];
	NSUInteger _imageDownloaded[2];
	NSMutableDictionary* _imageView;
	
	LTTextImageScrollView* _zoomedImageView;
}
@end

@implementation LTTextPageView

@synthesize index = _index;
@synthesize layouter = _layouter;

- (id)initWithFrame:(CGRect)frame layouter:(LTTextLayouter*)layouter pageIndex:(NSUInteger)index
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
		self.autoresizingMask = UIViewAutoresizingNone;
		self.autoresizesSubviews = NO;
		_layouter = [layouter retain];
		_index = index;
		self.backgroundColor = _layouter.backgroundColor;
		self.opaque = NO;
		_isNeedShowAttachments = YES;
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_imageDownloaded:) name:@"DTLazyImageViewDidFinishLoading" object:nil];
		
		UITapGestureRecognizer* gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_viewTapped:)];
		[self addGestureRecognizer:gr];
		[gr release];
    }
    return self;
}

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@, %u: %@", [super description], _index, _layouter];
}

-(void)_viewTapped:(UITapGestureRecognizer*)gr
{
	[[UIApplication sharedApplication] sendAction:@selector(lt_textPageViewTapped:) to:nil from:self forEvent:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
	LTTextMethodDebugLog();
	
	LTTextRelease(_zoomedImageView);
	
	LTTextRelease(_imageSizes[0]);
	LTTextRelease(_imageSizes[1]);
	LTTextRelease(_imageView);
    LTTextRelease(_layouter);
    [super dealloc];
}

#pragma mark - Images

- (void)lt_imageSelected:(LTTextImageView*)imageView
{
	[_zoomedImageView removeFromSuperview];
	LTTextRelease(_zoomedImageView);
	
	
	[[LTImageDownloader sharedInstance] downloadImageWithURL:imageView.attachment.contentURL
												 imageBounds:CGSizeZero
													 options:nil
												  completion:
	 ^(UIImage *image, NSError *error) {
		 if (image) {
			 _zoomedImageView = [[LTTextImageScrollView alloc] initWithFrame:self.bounds image:image];
			 [self addSubview:_zoomedImageView];
			 _zoomedImageView.alpha = 0.0;
			 [UIView animateWithDuration:0.25 animations:^(void) {
				 _zoomedImageView.alpha = 1.0; 
			 }];
			 
			 UIScrollView* superview = (id)self.superview;
			 superview.scrollEnabled = NO;
			 
		 }
	 }];
}

-(void)lt_zoomedImageViewClose:(LTTextImageScrollView*)zoomedImageView
{
	UIScrollView* superview = (id)self.superview;
	superview.scrollEnabled = YES;
	
	[UIView animateWithDuration:0.25 animations:^(void) {
		_zoomedImageView.alpha = 0.0;
	} completion:^(BOOL finished) {
		[_zoomedImageView removeFromSuperview];
		LTTextRelease(_zoomedImageView);
	}];
}

- (void)showAttachmentsIfNeeded
{
	if (_isNeedShowAttachments) {
		_isNeedShowAttachments = NO;
	} else {
		return;
	}
	
	LTTextRelease(_imageView);
	_imageView = [[NSMutableDictionary alloc] init];
	
	for (int i = 0; i < _layouter.columnCount; i++) {
		LTTextRelease(_imageSizes[i]);
		_imageSizes[i] = [[NSMutableArray alloc] init];
		
		NSArray* attachments = [_layouter imageAttachmentsAtPageIndex:_index column:i];
		CGRect imageFrame = [_layouter imageFrameAtPageIndex:_index column:i];
		
		NSUInteger ai = 0;
		for (NSDictionary* dict in attachments) {
			DTTextAttachment* att = [dict objectForKey:@"attachment"];
			
			[_imageSizes[i] addObject:[NSValue valueWithCGSize:CGSizeZero]];
			
			//NSLog(@"%@: %@,%@,%@, %@, %@", att, NSStringFromCGSize(att.displaySize), NSStringFromCGSize(att.originalSize), att.contents, att.contentURL, NSStringFromCGPoint(p));
			
			NSDictionary* options = [NSDictionary dictionaryWithObjectsAndKeys:
									 [UIColor lightGrayColor], LTImageDownloaderOptionBorderColor,
									 [NSNumber numberWithFloat:1.0f], LTImageDownloaderOptionBorderWidth, nil];
			
			//LTDummyObject* dummyObject = [[[LTDummyObject alloc] init] autorelease];
			
			[[LTImageDownloader sharedInstance] downloadImageWithURL:att.contentURL
														 imageBounds:CGSizeMake(imageFrame.size.width, imageFrame.size.width) 
															 options:options
														  completion:
			 ^(UIImage *image, NSError *error) {
				 if (image) {
					 [_imageSizes[i] replaceObjectAtIndex:ai withObject:[NSValue valueWithCGSize:image.size]];
					 
					// [dummyObject doSomething];
					 
					 LTTextImageView* imageView = [[LTTextImageView alloc] initWithFrame:CGRectZero];
					 imageView.image = image;
					 imageView.backgroundColor = [UIColor colorWithWhite:1 alpha:0.2];
					 imageView.contentMode = UIViewContentModeBottom;
					 NSLog(@"Download OK %@ : %@", att.contentURL, NSStringFromCGRect(imageView.frame));
					 imageView.alpha = 0.0;
					 [self addSubview:imageView];
					 [imageView release];
					 
					 [_imageView setObject:imageView forKey:[NSString stringWithFormat:@"%d-%d-%d", _index, i, ai]];
					 
				 }
				 
				 _imageDownloaded[i]++;
				 if (_imageDownloaded[i] == [_imageSizes[i] count]) {
					 // Image downloaded, layout image
					 NSArray* sizes = _imageSizes[i];
					 NSArray* frames = [_layouter imageFrameWithImageSizes:sizes atPageIndex:_index column:i];
					 for (int ii = 0; ii < frames.count; ii++) {
						 CGRect frame = [[frames objectAtIndex:ii] CGRectValue];
						 LTTextImageView* imageView = [_imageView objectForKey:[NSString stringWithFormat:@"%d-%d-%d", _index, i, ii]];
						 NSArray* attachments = [_layouter imageAttachmentsAtPageIndex:_index column:i];
						 imageView.frame = frame;
						 imageView.attachment = [[attachments objectAtIndex:ii] objectForKey:@"attachment"];
						 NSLog(@"imageView: %@", imageView);
					 }
					 
					 [UIView animateWithDuration:0.25 animations:^(void) {
						 for (UIView* view in self.subviews) {
							 if ([view isKindOfClass:[UIImageView class]] && view.alpha == 0.0) {
								 view.alpha = 1.0; 
							 }
						 }
					 }];
				 }
			 }];
			
			ai++;
		}
		
	}
}


// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
	LTTextMethodDebugLog();
	
	CGContextRef context = UIGraphicsGetCurrentContext();
    // Drawing code
	
	CGContextScaleCTM(context, 1.0, -1.0);
	CGContextTranslateCTM(context, 0, -self.bounds.size.height);
	
	dispatch_async(dispatch_get_main_queue(), ^(void) {
		[self showAttachmentsIfNeeded];
	});
	
	[_layouter drawInContext:context atPage:_index];
}


@end
