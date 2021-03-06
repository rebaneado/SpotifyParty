//
//  EventViewController.m
//  SpotifyParty
//
//  Created by Diego de Jesus Ramirez on 24/07/20.
//  Copyright © 2020 DiegoRamirez. All rights reserved.
//

#import <Parse/Parse.h>
#import "EventViewController.h"
#import "SongViewController.h"
#import "UIImageView+AFNetworking.h"
#import "APIManager.h"
#import "AppDelegate.h"
#import "Song.h"
#import "SongTableViewCell.h"
#import "AddedSongs.h"
#import "EventQueue.h"

@interface EventViewController ()

@property (weak, nonatomic) IBOutlet UIImageView *posterImageView;
@property (weak, nonatomic) IBOutlet UILabel *eventNameLabel;
@property (strong, nonatomic) AppDelegate *delegate;
@property (strong, nonatomic) NSMutableArray *songs;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) APIManager *apiManager;
@property (weak, nonatomic) IBOutlet UITextField *songsURLField;
@property (weak, nonatomic) IBOutlet UIButton *addSongButton;
@property (weak, nonatomic) IBOutlet UIButton *startNewSongButton;

@end

@implementation EventViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Set self as dataSource and delegate for the tableView
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    
    // Set the app delegate, to see the users access tokens
    self.delegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    self.apiManager = [[APIManager alloc] initWithToken:self.delegate.sessionManager.session.accessToken];
    // Set poster to nil to remove the old one (when refreshing) and query for the new one
    self.posterImageView.image = nil;
    [self.posterImageView setImageWithURL:[NSURL URLWithString: self.event.playlist.imageURLString]];
    
    self.eventNameLabel.text = self.event.eventName;
    
    self.songs = [[NSMutableArray alloc] init];
    [self fetchSongs];
    
}

- (void) viewDidAppear:(BOOL)animated {
    self.navigationController.navigationBar.subviews.firstObject.alpha = 0.6;

}

- (void) fetchSongs {
    
    [self.apiManager getPlaylistTracks:self.event.playlist.spotifyID withCompletion:^(NSDictionary * _Nonnull responseData, NSError * _Nonnull error) {
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
        } else {
            NSArray *songs = responseData[@"items"];
            
            for (NSDictionary *dictionary in songs) {
                // Allocate memory for object and initialize with the dictionary
                Song *song = [[Song alloc] initWithDictionary:dictionary[@"track"]];
                
                // Add the object to the Playlist's array
                [self.songs addObject:song];
            }
            
            [self.tableView reloadData];
        }
    }];
}

- (IBAction)shareTapped:(id)sender {
    NSURL *url = [NSURL URLWithString:[@"spotify-party-app-login://event/" stringByAppendingString:self.event.objectId]];
    
    // Add the qr image as an activity item and present the sharing view controller
    NSArray *activityItems = @[url];
    UIActivityViewController *activityViewControntroller = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    
    activityViewControntroller.excludedActivityTypes = @[];
    if (UI_USER_INTERFACE_IDIOM()  == UIUserInterfaceIdiomPad) {
        activityViewControntroller.popoverPresentationController.sourceView = self.view;
        activityViewControntroller.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/4, 0, 0);
    }
    
    [self presentViewController:activityViewControntroller animated:true completion:nil];
}

- (IBAction)addSongTapped:(id)sender {
    [UIView animateWithDuration:0.1 animations:^{
        self.startNewSongButton.alpha = 0;
        self.eventNameLabel.alpha = 0;
        self.songsURLField.alpha = 1;
        self.addSongButton.alpha = 1;
    }];
}

- (IBAction)addSongAction:(id)sender {
    if(self.songsURLField.hasText) {
        NSArray *urlComponents = [self.songsURLField.text componentsSeparatedByString:@"/"];
        NSString *path = urlComponents[4];
        NSString *trackURI = [path componentsSeparatedByString:@"?"][0];
        
        
        [self.apiManager getTrack:trackURI withCompletion:^(NSDictionary * _Nonnull responseData, NSError * _Nonnull error) {
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
            } else {
                Song *song = [[Song alloc] initWithDictionary:responseData];
                [self.songs insertObject:song atIndex:0];
                [self.tableView reloadData];
            
                EventQueue *addSong = [[EventQueue alloc] initAddSong:trackURI inEvent:self.event];
                [addSong saveInBackgroundWithBlock:^(BOOL succeeded, NSError * _Nullable error) {
                    if (succeeded) {
                        self.songsURLField.text = @"";
                        
                        [UIView animateWithDuration:0.1 animations:^{
                            self.startNewSongButton.alpha = 1;
                            self.eventNameLabel.alpha = 1;
                            self.songsURLField.alpha = 0;
                            self.addSongButton.alpha = 0;
                        }];
                    } else {
                        NSLog(@"%@", error.localizedDescription);
                    }
                }];
            }
        }];
        
        [self.view endEditing:YES];
    }
}


- (IBAction)pushChanges:(id)sender {
    PFQuery *query = [PFQuery queryWithClassName:@"AddedSongs"];
    
    [query whereKey:@"event" equalTo:self.event];
    
    // fetch data asynchronously
    [query findObjectsInBackgroundWithBlock:^(NSArray *newSongs, NSError *error) {
        if (newSongs != nil && !error) {
            
            NSMutableArray *songsURIS = [[NSMutableArray alloc] init];
            
            for (PFObject *song in newSongs) {
                NSString *songURI = song[@"songURI"];
                
                [songsURIS addObject:songURI];
            }
            
            NSArray *uris = [songsURIS copy];
            
            [self.apiManager postTracksToPlaylist:uris toPlaylist:self.event.playlist.spotifyID withCompletion:^(NSDictionary * _Nonnull responseData, NSError * _Nonnull error) {
                if (error) {
                    NSLog(@"Error :%@", error.localizedDescription);
                } else {
                    NSLog(@"Songs posted succesfully");
                    
                    [self fetchSongs];
                    [self.tableView reloadData];
                    
                    for (PFObject *song in newSongs) {
                        [song deleteInBackground];
                    }
                }
            }];
            
        } else {
            NSLog(@"%@", error.localizedDescription);
        }
    }];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    
    SongTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"SongTableViewCell"];
    cell.userInteractionEnabled = YES;
    
    Song *song = self.songs[indexPath.row];
    
    cell.event = self.event;
    cell.songName.text = song.name;
    cell.authorName.text = song.authorName;
    cell.songURI = song.spotifyID;
    
    [cell.albumImage setImageWithURL:[NSURL URLWithString: song.imageURL]];
    cell.albumImage.layer.cornerRadius = 5;
    
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.songs.count;
}

- (IBAction)tapped:(id)sender {
    [self.view endEditing:YES];
    
    [UIView animateWithDuration:0.1 animations:^{
        self.startNewSongButton.alpha = 1;
        self.eventNameLabel.alpha = 1;
        self.songsURLField.alpha = 0;
        self.addSongButton.alpha = 0;
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Remove the editing and possible open views 
    [self.view endEditing:YES];
    
    [UIView animateWithDuration:0.1 animations:^{
        self.startNewSongButton.alpha = 1;
        self.eventNameLabel.alpha = 1;
        self.songsURLField.alpha = 0;
        self.addSongButton.alpha = 0;
    }];
    
    // Set the tappedCell as the cell that initiated the segue
    UITableViewCell *tappedCell = sender;
    
    // Get the corresponding indexPath of that cell
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)tappedCell];
    
    // Get the cell corresponding to that cell
    Song *song = self.songs[indexPath.row];
    
    // Set the viewController to segue into and pass the movie object
    SongViewController *songViewController = [segue destinationViewController];
    songViewController.song = song;
}

@end
