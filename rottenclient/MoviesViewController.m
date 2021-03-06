//
//  MoviesViewController.m
//  rottenclient
//
//  Created by Naeim Semsarilar on 2/3/15.
//  Copyright (c) 2015 naeim. All rights reserved.
//

#import "MoviesViewController.h"
#import "MovieCell.h"
#import "UIImageView+AFNetworking.h"
#import "MovieDetailViewController.h"
#import "SVProgressHUD.h"
#import "UIImageView+NSAdditions.h"

@interface MoviesViewController () <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate, UITabBarDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic, strong) NSArray *movies;
@property (nonatomic, strong) NSArray *allMovies;
@property (nonatomic, strong) UIRefreshControl *refreshControl;
@property (weak, nonatomic) IBOutlet UILabel *networkError;
@property (nonatomic, strong) UISearchBar *searchBar;
@property (weak, nonatomic) IBOutlet UITabBar *tabBar;
@property (weak, nonatomic) IBOutlet UITabBarItem *boxOfficeTab;
@property (weak, nonatomic) IBOutlet UITabBarItem *dvdsTab;


-(void)makeMovieListRequest:(NSString*)endpointUrl completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))completionHandler ;
@end

@implementation MoviesViewController

NSString* apiKey = @"uv9vztvx4nqmbcde5qbtne9h";
NSString* moviesListFormat = @"http://api.rottentomatoes.com/api/public/v1.0/lists/movies/%@.json?country=us&apikey=%@";
NSString* dvdsListFormat = @"http://api.rottentomatoes.com/api/public/v1.0/lists/dvds/%@.json?country=us&apikey=%@";
NSString* boxOfficeListEndpoint;
NSString* topRentalsListEndpoint;

- (void)viewDidLoad {
    [super viewDidLoad];

    // configure endpoints
    boxOfficeListEndpoint = [NSString stringWithFormat:moviesListFormat, @"box_office", apiKey];
    topRentalsListEndpoint = [NSString stringWithFormat:dvdsListFormat, @"top_rentals", apiKey];
    
    
    // configure table view
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.tableView registerNib:[UINib nibWithNibName:@"MovieCell" bundle:nil] forCellReuseIdentifier:@"MovieCell"];
    self.tableView.rowHeight = 80;
    self.tableView.hidden = YES;
    
    // search bar
    self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 375, 40)];
    self.searchBar.delegate = self;

    // configure navigation bar
    self.navigationController.navigationBar.translucent = NO;
    self.navigationItem.titleView = self.searchBar;
    
    // refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(onRefresh) forControlEvents:UIControlEventValueChanged];
    [self.tableView insertSubview:self.refreshControl atIndex:0];
    [self.refreshControl removeConstraints:self.refreshControl.constraints];
    
    // network error
    self.networkError.frame = CGRectMake(0, 0, 375, 60);
    self.networkError.hidden = YES;
    
    // tab bar
    self.tabBar.delegate = self;
    self.tabBar.selectedItem = self.boxOfficeTab;

    // progress hud customization
    [SVProgressHUD setBackgroundColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0.5]];
    [SVProgressHUD setForegroundColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:0.9]];
    
    // make request to get data, show HUD the first time
    [SVProgressHUD show];
    [self onRefresh];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

- (void)makeMovieListRequest:(NSString*)endpointUrl completionHandler:(void (^)(NSURLResponse *response, NSData *data, NSError *connectionError))completionHandler {
    NSURL *url = [NSURL URLWithString:endpointUrl];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [NSURLConnection sendAsynchronousRequest:request queue:[NSOperationQueue mainQueue] completionHandler:completionHandler];
}

- (void)onRefresh {
    self.networkError.hidden = YES;

    NSString *endpoint;
    if (self.tabBar.selectedItem == self.boxOfficeTab) {
        endpoint = boxOfficeListEndpoint;
    } else if (self.tabBar.selectedItem == self.dvdsTab) {
        endpoint = topRentalsListEndpoint;
    }
    
    [self makeMovieListRequest:endpoint completionHandler:^void (NSURLResponse *response, NSData *data, NSError *connectionError) {
        [self.refreshControl endRefreshing]; // good thing endRefreshing is idempotent
        [SVProgressHUD dismiss];  // good thing dismiss is idempotent

        if (data == nil || connectionError != nil) {
            self.networkError.hidden = NO;
            return;
        }
        
        // parse the response and reload data
        NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        self.allMovies = responseDictionary[@"movies"];
        
        if (self.allMovies == nil) {
            self.networkError.hidden = NO;
            return;
        }

        [self filterMovies];
        [self.tableView reloadData];
        self.tableView.hidden = NO;
    }];
}

- (void) filterMovies {
    NSPredicate *p = [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary *bindings) {
        NSString* search = self.searchBar.text;
        if ([search length] == 0) {
            return YES;
        }
        
        NSString* title = evaluatedObject[@"title"];
        
        if ([[title lowercaseString] rangeOfString:[search lowercaseString]].location != NSNotFound) {
            return YES;
        } else {
            return NO;
        }
    }];
    
    self.movies = [self.allMovies filteredArrayUsingPredicate:p];
}

#pragma mark - Table methods

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.movies.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    MovieCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MovieCell" forIndexPath:indexPath];
    
    NSDictionary *movie = self.movies[indexPath.row];
    
    // set up cell UI
    cell.titleLabel.text = movie[@"title"];
    
    NSInteger audienceScore = [[movie valueForKeyPath:@"ratings.audience_score"] integerValue];
    NSString* audienceRating = [movie valueForKeyPath:@"ratings.audience_rating"];
    if (!audienceRating) {
        audienceRating = @"WTS";
    }
    NSInteger criticsScore = [[movie valueForKeyPath:@"ratings.critics_score"] integerValue];
    NSString* criticsRating = [movie valueForKeyPath:@"ratings.critics_rating"];
    
    if (audienceScore >= 0) {
        cell.audienceRating.text = [NSString stringWithFormat:@"%ld%%", audienceScore];
        [cell.audienceIcon setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@.png", audienceRating]]];
    } else {
        cell.audienceRating.hidden = YES;
        cell.audienceIcon.hidden = YES;
    }
    
    if (criticsScore >= 0) {
        cell.criticsRating.text = [NSString stringWithFormat:@"%ld%%", criticsScore];
        [cell.criticsIcon setImage:[UIImage imageNamed:[NSString stringWithFormat:@"%@.png", criticsRating]]];
    } else {
        cell.criticsRating.hidden = YES;
        cell.criticsIcon.hidden = YES;
    }
    
    // mpaa
    NSString* mpaa = movie[@"mpaa_rating"];
    if (mpaa && [mpaa length] > 0) {
        cell.mpaaLabel.layer.borderColor = [UIColor grayColor].CGColor;
        cell.mpaaLabel.layer.borderWidth = 1.0;
        cell.mpaaLabel.text = [NSString stringWithFormat:@" %@ ", mpaa];
        [cell.mpaaLabel sizeToFit];
    } else {
        cell.mpaaLabel.hidden = YES;
    }
    
    NSString *url = [movie valueForKeyPath:@"posters.thumbnail"];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [cell.posterView fadeInImageWithURLRequest:request placeholderImage:nil];
    
    //cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MovieDetailViewController *vc = [[MovieDetailViewController alloc] init];
    
    vc.movie = self.movies[indexPath.row];
    
    [self.navigationController pushViewController:vc animated:YES];
}

#pragma mark - Search bar methods

-(void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    [self filterMovies];
    [self.tableView reloadData];
}

#pragma mark - Tab bar methods

-(void)tabBar:(UITabBar *)tabBar didSelectItem:(UITabBarItem *)item {
    [SVProgressHUD show];
    [self onRefresh];
}



@end
