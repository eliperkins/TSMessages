//
//  TSMessageView.m
//  Felix Krause
//
//  Created by Felix Krause on 24.08.12.
//  Copyright (c) 2012 Felix Krause. All rights reserved.
//

#import "TSMessageView.h"
#import "HexColor.h"
#import "TSBlurView.h"
#import "TSMessage.h"
#import <FLKAutoLayout/UIView+FLKAutoLayout.h>


#define TSMessageViewPadding 15.0

#define TSDesignFileName @"TSMessagesDefaultDesign.json"


static NSMutableDictionary *_notificationDesign;

@interface TSMessage (TSMessageView)
- (void)fadeOutNotification:(TSMessageView *)currentView; // private method of TSMessage, but called by TSMessageView in -[fadeMeOut]
@end

@interface TSMessageView () <UIGestureRecognizerDelegate>

/** The displayed title of this message */
@property (nonatomic, strong) NSString *title;

/** The displayed subtitle of this message view */
@property (nonatomic, strong) NSString *subtitle;

/** The title of the added button */
@property (nonatomic, strong) NSString *buttonTitle;

/** The view controller this message is displayed in */
@property (nonatomic, strong) UIViewController *viewController;


/** Internal properties needed to resize the view on device rotation properly */
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *contentLabel;
@property (nonatomic, strong) UIImageView *iconImageView;
@property (nonatomic, strong) UIButton *button;
@property (nonatomic, strong) UIView *borderView;
@property (nonatomic, strong) UIImageView *backgroundImageView;
@property (nonatomic, strong) TSBlurView *backgroundBlurView; // Only used in iOS 7

@property (nonatomic, assign) CGFloat textSpaceLeft;
@property (nonatomic, assign) CGFloat textSpaceRight;

@property (nonatomic, assign) TSMessageNotificationType type;

@property (copy) void (^callback)();
@property (copy) void (^buttonCallback)();

- (CGFloat)updateHeightOfMessageView;
- (void)layoutSubviews;

@end


@implementation TSMessageView

+ (NSMutableDictionary *)notificationDesign
{
    if (!_notificationDesign)
    {
        NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:TSDesignFileName];
        _notificationDesign = [NSMutableDictionary dictionaryWithDictionary:[NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                                                                            options:kNilOptions
                                                                                                              error:nil]];
    }
    
    return _notificationDesign;
}


+ (void)addNotificationDesignFromFile:(NSString *)filename
{
    NSString *path = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:filename];
    NSDictionary *design = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:path]
                                                           options:kNilOptions
                                                             error:nil];
    
    [[TSMessageView notificationDesign] addEntriesFromDictionary:design];
}

- (id)initWithTitle:(NSString *)title
           subtitle:(NSString *)subtitle
              image:(UIImage *)image
               type:(TSMessageNotificationType)notificationType
           duration:(CGFloat)duration
   inViewController:(UIViewController *)viewController
           callback:(void (^)())callback
        buttonTitle:(NSString *)buttonTitle
     buttonCallback:(void (^)())buttonCallback
         atPosition:(TSMessageNotificationPosition)position
canBeDismissedByUser:(BOOL)dismissingEnabled
{
    NSDictionary *notificationDesign = [TSMessageView notificationDesign];
    
    if ((self = [self init]))
    {
        _title = title;
        _subtitle = subtitle;
        _buttonTitle = buttonTitle;
        _duration = duration;
        _viewController = viewController;
        _messagePosition = position;
        _type = notificationType;
        self.callback = callback;
        self.buttonCallback = buttonCallback;
        
        NSDictionary *current;
        NSString *currentString;
        switch (notificationType)
        {
            case TSMessageNotificationTypeMessage:
            {
                currentString = @"message";
                break;
            }
            case TSMessageNotificationTypeError:
            {
                currentString = @"error";
                break;
            }
            case TSMessageNotificationTypeSuccess:
            {
                currentString = @"success";
                break;
            }
            case TSMessageNotificationTypeWarning:
            {
                currentString = @"warning";
                break;
            }
                
            default:
                break;
        }
        
        current = [notificationDesign valueForKey:currentString];
        
        
        if (!image && [[current valueForKey:@"imageName"] length])
        {
            image = [UIImage imageNamed:[current valueForKey:@"imageName"]];
        }
        
        BOOL useBackgroundImage = [current[@"useBackgroundImage"] boolValue];
        if (useBackgroundImage)
        {
            // add background image here
            UIImage *backgroundImage = [UIImage imageNamed:[current valueForKey:@"backgroundImageName"]];
            NSDictionary *edgeValues = [current objectForKey:@"backgroundImageCapInsets"];
            if (edgeValues) {
                UIEdgeInsets edgeInsets = UIEdgeInsetsMake([[edgeValues objectForKey:@"top"] floatValue],
                                                           [[edgeValues objectForKey:@"left"] floatValue],
                                                           [[edgeValues objectForKey:@"bottom"] floatValue],
                                                           [[edgeValues objectForKey:@"right"] floatValue]);
                backgroundImage = [backgroundImage resizableImageWithCapInsets:edgeInsets resizingMode:UIImageResizingModeStretch];
            } else {
                backgroundImage = [backgroundImage stretchableImageWithLeftCapWidth:0.0 topCapHeight:0.0];
            }
            _backgroundImageView = [[UIImageView alloc] initWithImage:backgroundImage];
            [self addSubview:self.backgroundImageView];
        }
        else
        {
            // On iOS 7 and above use a blur layer instead (not yet finished)
            _backgroundBlurView = [[TSBlurView alloc] init];
            self.backgroundBlurView.blurTintColor = [UIColor colorWithHexString:current[@"backgroundColor"]];
            [self addSubview:self.backgroundBlurView];
        }
        
        UIColor *fontColor = [UIColor colorWithHexString:[current valueForKey:@"textColor"]
                                                   alpha:1.0];
        
        
        self.textSpaceLeft = 2 * TSMessageViewPadding;
        if (image) self.textSpaceLeft += image.size.width + 2 * TSMessageViewPadding;
        
        // Set up title label
        _titleLabel = [[UILabel alloc] init];
        [self.titleLabel setText:title];
        [self.titleLabel setTextColor:fontColor];
        [self.titleLabel setBackgroundColor:[UIColor clearColor]];
        CGFloat fontSize = [[current valueForKey:@"titleFontSize"] floatValue];
        NSString *fontName = [current valueForKey:@"titleFontName"];
        if (fontName != nil) {
            [self.titleLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
        } else {
            [self.titleLabel setFont:[UIFont boldSystemFontOfSize:fontSize]];
        }
        [self.titleLabel setShadowColor:[UIColor colorWithHexString:[current valueForKey:@"shadowColor"] alpha:1.0]];
        [self.titleLabel setShadowOffset:CGSizeMake([[current valueForKey:@"shadowOffsetX"] floatValue],
                                                    [[current valueForKey:@"shadowOffsetY"] floatValue])];
        self.titleLabel.numberOfLines = 0;
        self.titleLabel.lineBreakMode = NSLineBreakByWordWrapping;
        [self addSubview:self.titleLabel];
        
        // Set up content label (if set)
        if ([subtitle length])
        {
            _contentLabel = [[UILabel alloc] init];
            [self.contentLabel setText:subtitle];
            
            UIColor *contentTextColor = [UIColor colorWithHexString:[current valueForKey:@"contentTextColor"] alpha:1.0];
            if (!contentTextColor)
            {
                contentTextColor = fontColor;
            }
            [self.contentLabel setTextColor:contentTextColor];
            [self.contentLabel setBackgroundColor:[UIColor clearColor]];
            CGFloat fontSize = [[current valueForKey:@"contentFontSize"] floatValue];
            NSString *fontName = [current valueForKey:@"contentFontName"];
            if (fontName != nil) {
                [self.contentLabel setFont:[UIFont fontWithName:fontName size:fontSize]];
            } else {
                [self.contentLabel setFont:[UIFont systemFontOfSize:fontSize]];
            }
            [self.contentLabel setShadowColor:self.titleLabel.shadowColor];
            [self.contentLabel setShadowOffset:self.titleLabel.shadowOffset];
            self.contentLabel.lineBreakMode = self.titleLabel.lineBreakMode;
            self.contentLabel.numberOfLines = 0;
            
            [self addSubview:self.contentLabel];
        }
        
        if (image)
        {
            _iconImageView = [[UIImageView alloc] initWithImage:image];
            [self addSubview:self.iconImageView];
        }
        
        // Set up button (if set)
        if ([buttonTitle length])
        {
            _button = [UIButton buttonWithType:UIButtonTypeCustom];
            
            UIImage *buttonBackgroundImage = [[UIImage imageNamed:[current valueForKey:@"buttonBackgroundImageName"]] resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];
            
            if (!buttonBackgroundImage)
            {
                buttonBackgroundImage = [[UIImage imageNamed:[current valueForKey:@"NotificationButtonBackground"]] resizableImageWithCapInsets:UIEdgeInsetsMake(15.0, 12.0, 15.0, 11.0)];
            }
            
            [self.button setBackgroundImage:buttonBackgroundImage forState:UIControlStateNormal];
            [self.button setTitle:self.buttonTitle forState:UIControlStateNormal];
            
            UIColor *buttonTitleShadowColor = [UIColor colorWithHexString:[current valueForKey:@"buttonTitleShadowColor"] alpha:1.0];
            if (!buttonTitleShadowColor)
            {
                buttonTitleShadowColor = self.titleLabel.shadowColor;
            }
            
            [self.button setTitleShadowColor:buttonTitleShadowColor forState:UIControlStateNormal];
            
            UIColor *buttonTitleTextColor = [UIColor colorWithHexString:[current valueForKey:@"buttonTitleTextColor"] alpha:1.0];
            if (!buttonTitleTextColor)
            {
                buttonTitleTextColor = fontColor;
            }
            
            [self.button setTitleColor:buttonTitleTextColor forState:UIControlStateNormal];
            self.button.titleLabel.font = [UIFont boldSystemFontOfSize:14.0];
            self.button.titleLabel.shadowOffset = CGSizeMake([[current valueForKey:@"buttonTitleShadowOffsetX"] floatValue],
                                                             [[current valueForKey:@"buttonTitleShadowOffsetY"] floatValue]);
            [self.button addTarget:self
                            action:@selector(buttonTapped:)
                  forControlEvents:UIControlEventTouchUpInside];
            
            self.button.contentEdgeInsets = UIEdgeInsetsMake(0.0, 5.0, 0.0, 5.0);
            [self.button sizeToFit];
            
            [self addSubview:self.button];
            
            self.textSpaceRight = self.button.frame.size.width + TSMessageViewPadding;
        }
        
        // Add a border on the bottom (or on the top, depending on the view's postion)
        if (![TSMessage iOS7StyleEnabled])
        {
            _borderView = [[UIView alloc] initWithFrame:CGRectZero];
            self.borderView.backgroundColor = [UIColor colorWithHexString:[current valueForKey:@"borderColor"]
                                                                    alpha:1.0];
            [self addSubview:self.borderView];
        }
        
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self updateConstraints];
        
        if (dismissingEnabled)
        {
            UISwipeGestureRecognizer *gestureRec = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                             action:@selector(fadeMeOut)];
            [gestureRec setDirection:(self.messagePosition == TSMessageNotificationPositionTop ?
                                      UISwipeGestureRecognizerDirectionUp :
                                      UISwipeGestureRecognizerDirectionDown)];
            [self addGestureRecognizer:gestureRec];
            
            UITapGestureRecognizer *tapRec = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(fadeMeOut)];
            [self addGestureRecognizer:tapRec];
        }
        
        if (self.callback) {
            UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
            tapGesture.delegate = self;
            [self addGestureRecognizer:tapGesture];
        }
    }
    return self;
}

- (void)layoutSubviews
{
    [self updateConstraints];

    [super layoutSubviews];
    CGFloat availableLabelWidth = self.titleLabel.frame.size.width;
    self.titleLabel.preferredMaxLayoutWidth = availableLabelWidth;
    [self invalidateIntrinsicContentSize];

    [super layoutSubviews];
}

- (void)fadeMeOut
{
    [[TSMessage sharedMessage] performSelectorOnMainThread:@selector(fadeOutNotification:) withObject:self waitUntilDone:NO];
}

- (void)didMoveToWindow {
    [super didMoveToWindow];
    if (self.duration == TSMessageNotificationDurationEndless && self.superview && !self.window ) {
        // view controller was dismissed, let's fade out
        [self fadeMeOut];
    }
}

- (void)updateConstraints {
    NSDictionary *current;
    NSString *currentString;
    switch (self.type)
    {
        case TSMessageNotificationTypeMessage:
        {
            currentString = @"message";
            break;
        }
        case TSMessageNotificationTypeError:
        {
            currentString = @"error";
            break;
        }
        case TSMessageNotificationTypeSuccess:
        {
            currentString = @"success";
            break;
        }
        case TSMessageNotificationTypeWarning:
        {
            currentString = @"warning";
            break;
        }
            
        default:
            break;
    }
    NSDictionary *notificationDesign = [TSMessageView notificationDesign];
    current = [notificationDesign valueForKey:currentString];

    [self.backgroundImageView alignToView:self];
    [self.backgroundBlurView alignToView:self];

    [self.iconImageView alignLeadingEdgeWithView:self predicate:@"30"];
    [self.iconImageView alignTopEdgeWithView:self predicate:@"12"];
    
    [self.iconImageView constrainWidth:@"25" height:@"25"];
    
//    self.button.frame = CGRectMake(screenWidth - TSMessageViewPadding - self.button.frame.size.width,
//                                   0.0,
//                                   self.button.frame.size.width,
//                                   31.0);

    [self.borderView alignLeading:@"0" trailing:@"0" toView:self];
    [self.borderView constrainHeight:[[current valueForKey:@"borderHeight"] stringValue]];
    [self.borderView alignBottomEdgeWithView:self predicate:@"0"];

    [self.titleLabel constrainLeadingSpaceToView:self.iconImageView predicate:@"15"];
    [self.titleLabel alignTrailingEdgeWithView:self predicate:@"<=-30"];
    [self.titleLabel alignCenterYWithView:self predicate:@"0"];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.titleLabel setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisVertical];
    [self.titleLabel setContentCompressionResistancePriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    if (self.superview) {
        [self alignLeading:@"0" trailing:@"0" toView:self.superview];
    }
    
    [super updateConstraints];
}

- (CGSize)intrinsicContentSize {
    CGFloat titleHeight = self.titleLabel.intrinsicContentSize.height + (20 * 2);
    return CGSizeMake(320.0f, fmaxf(titleHeight, 50));
}

#pragma mark - Target/Action

- (void)buttonTapped:(id) sender
{
    if (self.buttonCallback)
    {
        self.buttonCallback();
    }
    
    [self fadeMeOut];
}

- (void)handleTap:(UITapGestureRecognizer *)tapGesture
{
    if (tapGesture.state == UIGestureRecognizerStateRecognized)
    {
        if (self.callback)
        {
            self.callback();
        }
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch
{
    return ! ([touch.view isKindOfClass:[UIControl class]]);
}

@end
