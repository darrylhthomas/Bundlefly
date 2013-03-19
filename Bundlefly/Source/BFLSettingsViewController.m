//
//  BFLSettingsViewController.m
//  Bundlefly
//
//  Created by Darryl H. Thomas on 3/13/13.
//  Copyright (c) 2013 Darryl H. Thomas. All rights reserved.
//
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// 1. Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
// DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
// ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
// ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
// SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


// IMPORTANT!!!! Do not use this for production builds.
// The functionality provided by NSBundle+ProxyBundle is accomplished through
// the use of runtime hacks and should be considered very fragile.

#import "BFLSettingsViewController.h"



@implementation BFLSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        self.title = NSLocalizedString(@"Settings", nil);
        self.tabBarItem = [[UITabBarItem alloc] initWithTitle:NSLocalizedString(@"Settings", nil) image:[UIImage imageNamed:@"bundlefly_settings_tabbar_item"] tag:3];
        
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self selector:@selector(handleKeyboardNotification:) name:UIKeyboardWillShowNotification object:nil];
    [notificationCenter addObserver:self selector:@selector(handleKeyboardNotification:) name:UIKeyboardWillHideNotification object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super viewWillDisappear:animated];
}

- (void)handleKeyboardNotification:(NSNotification *)notification
{
    CGRect keyboardFrameEnd = [self.view.window convertRect:[[notification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue] toView:self.tableView];
    
    CGFloat destinationMinY = MIN(CGRectGetMinY(keyboardFrameEnd), CGRectGetMaxY(self.tableView.bounds));
    CGFloat bottomInset = CGRectGetMaxY(self.tableView.bounds) - destinationMinY;
    
    NSTimeInterval duration = [[notification userInfo][UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    [UIView animateWithDuration:duration animations:^{
        self.tableView.contentInset = UIEdgeInsetsMake(0, 0, bottomInset, 0);
    }];
}

@end

#pragma mark -

@implementation BFLTextFieldTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _textField = [[UITextField alloc] initWithFrame:CGRectZero];
        _textField.returnKeyType = UIReturnKeyDone;
        
        [self.contentView addSubview:_textField];
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect contentBounds = self.contentView.bounds;
    CGFloat labelWidthAllotment = roundf(contentBounds.size.width / 2.0f);

    CGRect rect = self.textLabel.frame;
    rect.size.width = labelWidthAllotment - rect.origin.x;
    self.textLabel.frame = rect;
    
    [self.textField sizeToFit];
    rect = self.textField.frame;
    rect.origin.x = labelWidthAllotment;
    rect.origin.y = (contentBounds.size.height - rect.size.height) / 2.0f;
    rect.size.width = contentBounds.size.width - labelWidthAllotment - self.textLabel.frame.origin.x;
    self.textField.frame = rect;
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    
    self.textField.text = nil;
    self.textField.placeholder = nil;
}

@end

#pragma mark -

@implementation BFLSwitchTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        _switchControl = [[UISwitch alloc] initWithFrame:CGRectZero];
        
        [self.contentView addSubview:_switchControl];
    }
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    CGRect contentBounds = self.contentView.bounds;
    CGFloat labelWidthAllotment = roundf(contentBounds.size.width / 2.0f);
    
    CGRect rect = self.textLabel.frame;
    rect.size.width = labelWidthAllotment - rect.origin.x;
    self.textLabel.frame = rect;
    
    [self.switchControl sizeToFit];
    rect = self.switchControl.frame;
    rect.origin.x = CGRectGetMaxX(contentBounds) - rect.size.width - self.textLabel.frame.origin.x;
    rect.origin.y = (contentBounds.size.height - rect.size.height) / 2.0f;
    self.switchControl.frame = rect;
}

@end
