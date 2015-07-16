//
// Created by Benoît on 11/01/14.
// Copyright (c) 2014 Pragmatic Code. All rights reserved.
//

#import "XCFPlugin.h"
#import "XCFXcodeFormatter.h"
#import "XCFDefaults.h"
#import "XCFPreferencesWindowController.h"
#import "XCFLoggingUtilities.h"
#import "BBLogging.h"

@import CoreServices;

@interface XCFPlugin ()
@property (nonatomic, readonly) XCFPreferencesWindowController *preferencesWindowController;
@end

@implementation XCFPlugin {}

@synthesize preferencesWindowController = _preferencesWindowController;

#pragma mark - Setup and Teardown

static XCFPlugin *sharedPlugin = nil;

+ (void)pluginDidLoad:(NSBundle *)plugin
{
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		sharedPlugin = [[self alloc] init];
		[XCFDefaults registerDefaults];
	});
}

- (id)init
{
	self = [super init];
	
	if (self) {
		[XCFLoggingUtilities setUpLogger];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidFinishLaunchingNotification:) name:NSApplicationDidFinishLaunchingNotification object:nil];
		
		DDLogVerbose(@"BBUncrustifyPlugin Version %@ loaded", [[[NSBundle bundleForClass:[self class]] infoDictionary] objectForKey:@"CFBundleVersion"]);
	}
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Actions

- (IBAction)formatSelectedFiles:(id)sender
{
	// should be improved to show all generated errors and not only the last one
	__block NSError *lastError = nil;
	
	[XCFXcodeFormatter formatSelectedFilesWithEnumerationBlock:^(NSURL *url, NSError *error, BOOL *stop) {
		if (error) {
			DDLogError(@"%@", error);
			lastError = error;
		}
	}];
	
	if (lastError) {
		[self presentFormattingError:lastError];
	}
}

- (IBAction)formatActiveFile:(id)sender
{
	NSError *error = nil;
	
	[XCFXcodeFormatter formatActiveFileWithError:&error];
	
	if (error) {
		DDLogError(@"%@", error);
		[self presentFormattingError:error];
	}
}

- (IBAction)formatSelectedLines:(id)sender
{
	NSError *error = nil;
	
	[XCFXcodeFormatter formatSelectedLinesWithError:&error];
	
	if (error) {
		DDLogError(@"%@", error);
		[self presentFormattingError:error];
	}
}

- (IBAction)launchConfigurationEditor:(id)sender
{
	NSError *error = nil;
	
	[XCFXcodeFormatter launchConfigurationEditorWithError:&error];
	
	if (error) {
		DDLogError(@"%@", error);
		[self presentFormattingError:error];
	}
}

- (IBAction)showPreferences:(id)sender
{
	[self.preferencesWindowController showWindow:nil];
	
	NSURL *url = [[NSBundle bundleForClass:[self class]] URLForResource:@"XCFPreferencesWindowController" withExtension:@"nib"];
	
	if (!url) {
		NSAlert *alert = [[NSAlert alloc] init];
		alert.messageText = @"BBUncrustify preferences could not be shown because the plugin is corrupted.";
		alert.informativeText = @"If you built the plugin from sources using Xcode, make sure to perform “Clean Build Folder“ in Xcode and then build the plugin again.\n\nIf you installed the plugin via Alctraz, there is a pending issue causing some files to be missing in the plugin. Prefer to install it via the plugin releases webpage.";
		[alert addButtonWithTitle:@"Download Latest Release"];
		[alert addButtonWithTitle:@"Cancel"];
		NSModalResponse result = [alert runModal];
		
		if (result == NSAlertFirstButtonReturn) {
			[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/benoitsan/BBUncrustifyPlugin-Xcode/releases"]];
		}
	}
}

- (IBAction)viewLog:(id)sender
{
	NSURL *logFileURL = [XCFLoggingUtilities mostRecentLogFileURL];
	
	if (logFileURL) {
		[[NSWorkspace sharedWorkspace] openURL:logFileURL];
	}
}

#pragma mark - Internal

- (void)initializeMenu
{
	NSMenuItem *editMenuItem = [[NSApp mainMenu] itemWithTitle:@"Edit"];
	
	if (editMenuItem) {
		[[editMenuItem submenu] addItem:[NSMenuItem separatorItem]];
		
		NSMenu *formatCodeMenu = [[NSMenu alloc] initWithTitle:@"Format Code"];
		
		NSMenuItem *menuItem;
		menuItem = [[NSMenuItem alloc] initWithTitle:@"Format Selected Files" action:@selector(formatSelectedFiles:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:@"Format Active File" action:@selector(formatActiveFile:) keyEquivalent:@"U"];
		[menuItem setKeyEquivalentModifierMask:NSControlKeyMask];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:@"Format Selected Lines" action:@selector(formatSelectedLines:) keyEquivalent:@"u"];
		[menuItem setKeyEquivalentModifierMask:NSControlKeyMask];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		[formatCodeMenu addItem:[NSMenuItem separatorItem]];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:@"Edit Configuration…" action:@selector(launchConfigurationEditor:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:@"BBUncrustifyPlugin Preferences…" action:@selector(showPreferences:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		menuItem = [[NSMenuItem alloc] initWithTitle:@"View Log" action:@selector(viewLog:) keyEquivalent:@""];
		[menuItem setTarget:self];
		[formatCodeMenu addItem:menuItem];
		
		NSMenuItem *formatCodeMenuItem = [[NSMenuItem alloc] initWithTitle:@"Format Code" action:nil keyEquivalent:@""];
		[formatCodeMenuItem setSubmenu:formatCodeMenu];
		[[editMenuItem submenu] addItem:formatCodeMenuItem];
	}
}

- (XCFPreferencesWindowController *)preferencesWindowController
{
	if (!_preferencesWindowController) {
		_preferencesWindowController = [[XCFPreferencesWindowController alloc] init];
	}
	return _preferencesWindowController;
}

- (void)presentFormattingError:(NSError *)error
{
	if (error) {
		if ([error.domain isEqualToString:XCFErrorDomain] && error.code == XCFFormatterMissingConfigurationError) {
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Configuration File Not Found", nil)
				defaultButton:NSLocalizedString(@"Open Preferences…", nil)
				alternateButton:NSLocalizedString(@"Cancel", nil)
				otherButton:nil
				informativeTextWithFormat:error.localizedDescription, nil];
				
			if ([alert runModal] == NSAlertDefaultReturn) {
				[self.preferencesWindowController showWindow:nil];
			}
		}
		else {
			[[NSAlert alertWithError:error] runModal];
		}
	}
}

#pragma mark - NSMenuValidation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if ([menuItem action] == @selector(formatSelectedFiles:)) {
		return [XCFXcodeFormatter canFormatSelectedFiles];
	}
	else if ([menuItem action] == @selector(formatActiveFile:)) {
		return [XCFXcodeFormatter canFormatActiveFile];
	}
	else if ([menuItem action] == @selector(formatSelectedLines:)) {
		return [XCFXcodeFormatter canFormatSelectedLines];
	}
	else if ([menuItem action] == @selector(launchConfigurationEditor:)) {
		NSString *formatter = @"";
		NSString *selectedFormatter = [[NSUserDefaults standardUserDefaults] stringForKey:XCFDefaultsKeySelectedFormatter];
		
		if ([selectedFormatter isEqualToString:XCFDefaultsFormatterValueClang]) {
			formatter = @"Clang";
		}
		else if ([selectedFormatter isEqualToString:XCFDefaultsFormatterValueUncrustify]) {
			formatter = @"Uncrustify";
		}
		
		menuItem.title = [NSString stringWithFormat:@"Edit %@ Configuration", formatter];
		
		return [XCFXcodeFormatter canLaunchConfigurationEditor];
	}
	return YES;
}

#pragma mark - Notifications

- (void)applicationDidFinishLaunchingNotification:(NSNotification *)notification
{
	static dispatch_once_t onceToken;
	
	dispatch_once(&onceToken, ^{
		[self initializeMenu];
	});
}

@end
