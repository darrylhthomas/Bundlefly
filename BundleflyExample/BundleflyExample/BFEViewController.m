//
//  BFEViewController.m
//  BundleflyExample
//
//  Created by Darryl H. Thomas on 3/13/13.
//  Copyright (c) 2013 Darryl H. Thomas. All rights reserved.
//

#import "BFEViewController.h"
#import "BFLBundleflyController.h"

@interface BFEViewController ()

@end

@implementation BFEViewController

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.imageView.image = [UIImage imageNamed:@"Icon"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)doSomething:(id)sender
{
    UIViewController *presentingController = [self presentingViewController];
    if (presentingController) {
        [presentingController dismissViewControllerAnimated:YES completion:^{
            [[BFLBundleflyController sharedController] attachToViewController:presentingController];
        }];
    } else {
        BFEViewController *controller = [[BFEViewController alloc] initWithNibName:@"BFEViewController" bundle:[NSBundle mainBundle]];
        [self presentViewController:controller animated:YES completion:^{
            [[BFLBundleflyController sharedController] attachToViewController:controller];
        }];
    }
}
@end
