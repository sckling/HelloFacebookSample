/*
 * Copyright 2010-present Facebook.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "HFViewController.h"

#import <CoreLocation/CoreLocation.h>

#import "HFAppDelegate.h"


@interface HFViewController () <FBLoginViewDelegate>

@property (strong, nonatomic) IBOutlet FBProfilePictureView *profilePic;
@property (strong, nonatomic) IBOutlet UIButton *buttonPostStatus;
@property (strong, nonatomic) IBOutlet UIButton *buttonPickPhotos;
@property (strong, nonatomic) IBOutlet UIButton *buttonPickAlbums;
@property (strong, nonatomic) IBOutlet UIButton *buttonPickVideos;
@property (strong, nonatomic) IBOutlet UILabel *labelFirstName;
@property (strong, nonatomic) id<FBGraphUser> loggedInUser;

- (IBAction)postStatusUpdateClick:(UIButton *)sender;
- (IBAction)pickPhotos:(UIButton *)sender;
- (IBAction)pickAlbums:(UIButton *)sender;
- (IBAction)pickVideos:(UIButton *)sender;

- (void)showAlert:(NSString *)message
           result:(id)result
            error:(NSError *)error;


@end

@implementation HFViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    NSLog(@"viewDidLoad");
    [super viewDidLoad];

    // Create Login View so that the app will be granted "status_update" permission.
    FBLoginView *loginview = [[FBLoginView alloc] initWithReadPermissions:@[@"public_profile", @"email", @"user_photos", @"user_videos"]];

    loginview.frame = CGRectOffset(loginview.frame, 5, 5);
#ifdef __IPHONE_7_0
#ifdef __IPHONE_OS_VERSION_MAX_ALLOWED
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
    if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        loginview.frame = CGRectOffset(loginview.frame, 5, 25);
    }
#endif
#endif
#endif
    loginview.delegate = self;

    [self.view addSubview:loginview];

    [loginview sizeToFit];
}

- (void)viewDidUnload {
    self.buttonPickAlbums = nil;
    self.buttonPickVideos = nil;
    self.buttonPickPhotos = nil;
    self.buttonPostStatus = nil;
    self.labelFirstName = nil;
    self.loggedInUser = nil;
    self.profilePic = nil;
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

#pragma mark - FBLoginViewDelegate

- (void)loginViewShowingLoggedInUser:(FBLoginView *)loginView {
    NSLog(@"loginViewShowingLoggedInUser");
    // first get the buttons set for login mode
    self.buttonPickPhotos.enabled = YES;
    self.buttonPostStatus.enabled = YES;
    self.buttonPickAlbums.enabled = YES;
    self.buttonPickVideos.enabled = YES;

    // "Post Status" available when logged on and potentially when logged off.  Differentiate in the label.
    [self.buttonPostStatus setTitle:@"Post Status Update (Logged On)" forState:self.buttonPostStatus.state];
}

- (void)loginViewFetchedUserInfo:(FBLoginView *)loginView
                            user:(id<FBGraphUser>)user {
    NSLog(@"loginViewFetchedUserInfo");
    // here we use helper properties of FBGraphUser to dot-through to first_name and
    // id properties of the json response from the server; alternatively we could use
    // NSDictionary methods such as objectForKey to get values from the my json object
    self.labelFirstName.text = [NSString stringWithFormat:@"Hello %@!", user.first_name];
    // setting the profileID property of the FBProfilePictureView instance
    // causes the control to fetch and display the profile picture for the user
    self.profilePic.profileID = user.objectID;
    self.loggedInUser = user;
}

- (void)loginViewShowingLoggedOutUser:(FBLoginView *)loginView {
    NSLog(@"loginViewShowingLoggedOutUser");
    // test to see if we can use the share dialog built into the Facebook application
    FBLinkShareParams *p = [[FBLinkShareParams alloc] init];
    p.link = [NSURL URLWithString:@"http://developers.facebook.com/ios"];
    BOOL canShareFB = [FBDialogs canPresentShareDialogWithParams:p];
    BOOL canShareiOS6 = [FBDialogs canPresentOSIntegratedShareDialogWithSession:nil];
    BOOL canShareFBPhoto = [FBDialogs canPresentShareDialogWithPhotos];

    self.buttonPostStatus.enabled = canShareFB || canShareiOS6;
    self.buttonPickPhotos.enabled = canShareFBPhoto;
    self.buttonPickAlbums.enabled = NO;
    self.buttonPickVideos.enabled = NO;

    // "Post Status" available when logged on and potentially when logged off.  Differentiate in the label.
    [self.buttonPostStatus setTitle:@"Post Status Update (Logged Off)" forState:self.buttonPostStatus.state];

    self.profilePic.profileID = nil;
    self.labelFirstName.text = nil;
    self.loggedInUser = nil;
}

- (void)loginView:(FBLoginView *)loginView handleError:(NSError *)error {
    // see https://developers.facebook.com/docs/reference/api/errors/ for general guidance on error handling for Facebook API
    // our policy here is to let the login view handle errors, but to log the results
    NSLog(@"FBLoginView encountered an error=%@", error);
}

#pragma mark -

// Convenience method to perform some action that requires the "publish_actions" permissions.
- (void)performPublishAction:(void(^)(void))action {
    // we defer request for permission to post to the moment of post, then we check for the permission
    if ([FBSession.activeSession.permissions indexOfObject:@"publish_actions"] == NSNotFound) {
        // if we don't already have the permission, then we request it now
        [FBSession.activeSession requestNewPublishPermissions:@[@"publish_actions"]
                                              defaultAudience:FBSessionDefaultAudienceFriends
                                            completionHandler:^(FBSession *session, NSError *error) {
                                                if (!error) {
                                                    action();
                                                } else if (error.fberrorCategory != FBErrorCategoryUserCancelled) {
                                                    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Permission denied"
                                                                                                        message:@"Unable to get permission to post"
                                                                                                       delegate:nil
                                                                                              cancelButtonTitle:@"OK"
                                                                                              otherButtonTitles:nil];
                                                    [alertView show];
                                                }
                                            }];
    } else {
        action();
    }

}
/*
- (IBAction)postStatusUpdateClick:(UIButton *)sender {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}
*/
// Post Status Update button handler; will attempt different approaches depending upon configuration.
- (IBAction)postStatusUpdateClick:(UIButton *)sender {
    // Post a status update to the user's feed via the Graph API, and display an alert view
    // with the results or an error.

    NSURL *urlToShare = [NSURL URLWithString:@"http://developers.facebook.com/ios"];

    // This code demonstrates 3 different ways of sharing using the Facebook SDK.
    // The first method tries to share via the Facebook app. This allows sharing without
    // the user having to authorize your app, and is available as long as the user has the
    // correct Facebook app installed. This publish will result in a fast-app-switch to the
    // Facebook app.
    // The second method tries to share via Facebook's iOS6 integration, which also
    // allows sharing without the user having to authorize your app, and is available as
    // long as the user has linked their Facebook account with iOS6. This publish will
    // result in a popup iOS6 dialog.
    // The third method tries to share via a Graph API request. This does require the user
    // to authorize your app. They must also grant your app publish permissions. This
    // allows the app to publish without any user interaction.

    // If it is available, we will first try to post using the share dialog in the Facebook app
    FBLinkShareParams *params = [[FBLinkShareParams alloc] initWithLink:urlToShare
                                                                   name:@"Hello Facebook"
                                                                caption:nil
                                                            description:@"The 'Hello Facebook' sample application showcases simple Facebook integration."
                                                                picture:nil];

    BOOL isSuccessful = NO;
    if ([FBDialogs canPresentShareDialogWithParams:params]) {
        FBAppCall *appCall = [FBDialogs presentShareDialogWithParams:params
                                                         clientState:nil
                                                             handler:^(FBAppCall *call, NSDictionary *results, NSError *error) {
                                                                 if (error) {
                                                                     NSLog(@"Error: %@", error.description);
                                                                 } else {
                                                                     NSLog(@"Success!");
                                                                 }
                                                             }];
        isSuccessful = (appCall  != nil);
    }
    if (!isSuccessful && [FBDialogs canPresentOSIntegratedShareDialogWithSession:[FBSession activeSession]]){
        // Next try to post using Facebook's iOS6 integration
        isSuccessful = [FBDialogs presentOSIntegratedShareDialogModallyFrom:self
                                                                initialText:nil
                                                                      image:nil
                                                                        url:urlToShare
                                                                    handler:nil];
    }
    if (!isSuccessful) {
        [self performPublishAction:^{
            NSString *message = [NSString stringWithFormat:@"Updating status for %@ at %@", self.loggedInUser.first_name, [NSDate date]];

            FBRequestConnection *connection = [[FBRequestConnection alloc] init];

            connection.errorBehavior = FBRequestConnectionErrorBehaviorReconnectSession
            | FBRequestConnectionErrorBehaviorAlertUser
            | FBRequestConnectionErrorBehaviorRetry;

            [connection addRequest:[FBRequest requestForPostStatusUpdate:message]
                 completionHandler:^(FBRequestConnection *innerConnection, id result, NSError *error) {
                     [self showAlert:message result:result error:error];
                     self.buttonPostStatus.enabled = YES;
                 }];
            [connection start];

            self.buttonPostStatus.enabled = NO;
        }];
    }
}

// Post Photo button handler
/*
- (IBAction)postPhotoClick:(UIButton *)sender {
  // Just use the icon image from the application itself.  A real app would have a more
  // useful way to get an image.
  UIImage *img = [UIImage imageNamed:@"Icon-72@2x.png"];
  BOOL canPresent = [FBDialogs canPresentShareDialogWithPhotos];
  NSLog(@"canPresent: %d", canPresent);
    
  FBPhotoParams *params = [[FBPhotoParams alloc] init];
  params.photos = @[img];

  BOOL isSuccessful = NO;
  if (canPresent) {
      FBAppCall *appCall = [FBDialogs presentShareDialogWithPhotoParams:params
                                                            clientState:nil
                                                                handler:^(FBAppCall *call, NSDictionary *results, NSError *error) {
                                                            if (error) {
                                                                    NSLog(@"Error: %@", error.description);
                                                                } else {
                                                                    NSLog(@"Success!");
                                                                }
                                                            }];
      isSuccessful = (appCall  != nil);
  }
  if (!isSuccessful) {
    [self performPublishAction:^{
      FBRequestConnection *connection = [[FBRequestConnection alloc] init];
      connection.errorBehavior = FBRequestConnectionErrorBehaviorReconnectSession
      | FBRequestConnectionErrorBehaviorAlertUser
      | FBRequestConnectionErrorBehaviorRetry;

      [connection addRequest:[FBRequest requestForUploadPhoto:img]
           completionHandler:^(FBRequestConnection *innerConnection, id result, NSError *error) {
             [self showAlert:@"Photo Post" result:result error:error];
             if (FBSession.activeSession.isOpen) {
               self.buttonPostPhoto.enabled = YES;
             }
           }];
      [connection start];

      self.buttonPostPhoto.enabled = NO;
    }];
  }
}
 */

- (IBAction)pickPhotos:(UIButton *)sender {

    [FBRequestConnection startWithGraphPath:@"/me/photos"
                                 parameters:nil
                                 HTTPMethod:@"GET"
                          completionHandler:^(FBRequestConnection *connection,
                                              id result,
                                              NSError *error) {
                              //NSLog(@"Result: %@", NSStringFromClass([result class]));
                              NSArray *data = [result valueForKey:@"data"];
                              //NSLog(@"Result: %d, %@", [data count], data[0]);
                              for (NSDictionary *dict in data) {
                                  NSLog(@"Photo names: %@", [dict objectForKey:@"source"]);
                              }
                          }];
}

- (IBAction)pickAlbums:(UIButton *)sender {

    [FBRequestConnection startWithGraphPath:@"/me/albums"
                                 parameters:nil
                                 HTTPMethod:@"GET"
                          completionHandler:^(FBRequestConnection *connection,
                                              id result,
                                              NSError *error) {
                              //NSLog(@"Result: %@", NSStringFromClass([result class]));
                              NSArray *data = [result valueForKey:@"data"];
                              //NSLog(@"Result: %d, %@", [data count], data[0]);
                              for (NSDictionary *dict in data) {
                                  NSLog(@"Album names: %@", [dict valueForKey:@"name"]);
                              }
                          }];
}

- (IBAction)pickVideos:(UIButton *)sender {

    [FBRequestConnection startWithGraphPath:@"/me/videos"
                                 parameters:nil
                                 HTTPMethod:@"GET"
                          completionHandler:^(FBRequestConnection *connection,
                                              id result,
                                              NSError *error) {
                              //NSLog(@"Result: %@", NSStringFromClass([result class]));
                              NSArray *data = [result valueForKey:@"data"];
                              //NSLog(@"Result: %d, %@", [data count], data[0]);
                              for (NSDictionary *dict in data) {
                                  NSLog(@"Video names: %@", [dict valueForKey:@"name"]);
                              }
                          }];
}

// UIAlertView helper for post buttons
- (void)showAlert:(NSString *)message
           result:(id)result
            error:(NSError *)error {

    NSString *alertMsg;
    NSString *alertTitle;
    if (error) {
        alertTitle = @"Error";
        // Since we use FBRequestConnectionErrorBehaviorAlertUser,
        // we do not need to surface our own alert view if there is an
        // an fberrorUserMessage unless the session is closed.
        if (error.fberrorUserMessage && FBSession.activeSession.isOpen) {
            alertTitle = nil;

        } else {
            // Otherwise, use a general "connection problem" message.
            alertMsg = @"Operation failed due to a connection problem, retry later.";
        }
    } else {
        NSDictionary *resultDict = (NSDictionary *)result;
        alertMsg = [NSString stringWithFormat:@"Successfully posted '%@'.", message];
        NSString *postId = [resultDict valueForKey:@"id"];
        if (!postId) {
            postId = [resultDict valueForKey:@"postId"];
        }
        if (postId) {
            alertMsg = [NSString stringWithFormat:@"%@\nPost ID: %@", alertMsg, postId];
        }
        alertTitle = @"Success";
    }

    if (alertTitle) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:alertTitle
                                                            message:alertMsg
                                                           delegate:nil
                                                  cancelButtonTitle:@"OK"
                                                  otherButtonTitles:nil];
        [alertView show];
    }
}



@end
