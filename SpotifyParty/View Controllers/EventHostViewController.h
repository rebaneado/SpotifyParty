//
//  EventHostViewController.h
//  SpotifyParty
//
//  Created by Diego de Jesus Ramirez on 02/08/20.
//  Copyright © 2020 DiegoRamirez. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Event.h"

NS_ASSUME_NONNULL_BEGIN

@interface EventHostViewController : UIViewController <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) Event *event;

@end

NS_ASSUME_NONNULL_END
