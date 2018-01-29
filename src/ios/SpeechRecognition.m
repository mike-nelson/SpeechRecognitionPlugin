//
//  Created by jcesarmobile on 30/11/14.
//  2017 mike-nelson added SFSpeechRecognizer
//

#import "SpeechRecognition.h"
#import "ISpeechSDK.h"
#import <Speech/Speech.h>

@implementation SpeechRecognition

- (void) init:(CDVInvokedUrlCommand*)command
{
    NSString * key = [self.commandDelegate.settings objectForKey:[@"apiKey" lowercaseString]];
    if (!key) {
        key = @"developerdemokeydeveloperdemokey";
    }
    iSpeechSDK *sdk = [iSpeechSDK sharedSDK];
    sdk.APIKey = key;
    self.iSpeechRecognition = [[ISSpeechRecognition alloc] init];
    self.audioEngine = [[AVAudioEngine alloc] init];
}

- (void) start:(CDVInvokedUrlCommand*)command
{
    self.command = command;
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"start" forKey:@"type"];
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
    [self recognize];

}

- (void) requestPermissionForMic:(CDVInvokedUrlCommand*)command
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }else{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Mic not allowed"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void) requestPermissionForRecognition:(CDVInvokedUrlCommand*)command
{
    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (granted) {
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:@"OK"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }else{
            CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Mic not allowed"];
            [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }
    }];
}

- (void) recognize
{
    NSString * lang = [self.command argumentAtIndex:0];
    if (lang && [lang isEqualToString:@"en"]) {
        lang = @"en-US";
    }

    [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
        if (!granted) {
            // Microphone disabled code
            [self sendErrorWithMessage:@"Mic not allowed" andCode:44];
            return;
        }
    }];
    
    
    if (NSClassFromString(@"SFSpeechRecognizer")) {
        
        
        //if (![self permissionIsSet]) {
            [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status){
                //dispatch_async(dispatch_get_main_queue(), ^{

                    if (status == SFSpeechRecognizerAuthorizationStatusAuthorized) {
                        [self recordAndRecognizeWithLang:lang];
                    } else {
                        [self sendErrorWithMessage:@"Permission not allowed" andCode:4];
                    }

               // });
            }];
        //} else {
        //    [self recordAndRecognizeWithLang:lang];
        //}
    } else {
        [self.iSpeechRecognition setDelegate:self];
        [self.iSpeechRecognition setLocale:lang];
        [self.iSpeechRecognition setFreeformType:ISFreeFormTypeDictation];
        NSError *error;
        if(![self.iSpeechRecognition listenAndRecognizeWithTimeout:10 error:&error]) {
            NSLog(@"ERROR: %@", error);
        }
    }
}

- (void) recordAndRecognizeWithLang:(NSString *) lang
{
    NSLocale *locale = [[NSLocale alloc] initWithLocaleIdentifier:lang];
    self.sfSpeechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:locale];
    if (!self.sfSpeechRecognizer) {
        [self sendErrorWithMessage:@"The language is not supported" andCode:7];
    } else {

        // Cancel the previous task if it's running.
        if ( self.recognitionTask ) {
            [self.recognitionTask cancel];
            self.recognitionTask = nil;
        }

        //[self initAudioSession];

        self.recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        self.recognitionRequest.shouldReportPartialResults = [[self.command argumentAtIndex:1] boolValue];
        
        self.sfSpeechRecognizer.delegate = self;
        
        self.recognitionTask = [self.sfSpeechRecognizer recognitionTaskWithRequest:self.recognitionRequest resultHandler:^(SFSpeechRecognitionResult *result, NSError *error) {
            NSLog(@"recognise");

            if (error) {
                NSLog(@"error %ld", error.code);
                // code 1 or 203 or 216 = we called abort via self.recognitionTask cancel
                // 1101 is thrown when in simulator
                // 1700 is when not given permission
                if (error.code==203){   //|| error.code==216
                    // nothing, carry on, this is bullshit
                }else{
                    [self stopAndRelease];
                    // note: we can't send error back to js as I found it crashes (when recognising, then switch apps, then come back)
                    [self sendErrorWithMessage:@"sfSpeechRecognizer Error" andCode:error.code];
                    return;
                }
            }

            if (result) {
                NSMutableArray * alternatives = [[NSMutableArray alloc] init];
                int maxAlternatives = [[self.command argumentAtIndex:2] intValue];
                for ( SFTranscription *transcription in result.transcriptions ) {
                    if (alternatives.count < maxAlternatives) {
                        float confMed = 0;
                        for ( SFTranscriptionSegment *transcriptionSegment in transcription.segments ) {
                            //NSLog(@"transcriptionSegment.confidence %f", transcriptionSegment.confidence);
                            confMed +=transcriptionSegment.confidence;
                        }
                        NSMutableDictionary * resultDict = [[NSMutableDictionary alloc]init];
                        [resultDict setValue:transcription.formattedString forKey:@"transcript"];
                        [resultDict setValue:[NSNumber numberWithBool:result.isFinal] forKey:@"final"];
                        [resultDict setValue:[NSNumber numberWithFloat:confMed/transcription.segments.count]forKey:@"confidence"];
                        [alternatives addObject:resultDict];
                    }
                }
                [self sendResults:@[alternatives]];
                if ( result.isFinal ) {
                    //NSLog(@"recog: isFinal");
                    [self stopAndRelease];
                }
            }
        }];

        //[self.audioEngine.inputNode disconnectNodeInput:0];
        AVAudioFormat *recordingFormat = [self.audioEngine.inputNode outputFormatForBus:0];
        [self.audioEngine.inputNode removeTapOnBus:0];
        [self.audioEngine.inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
 //           NSLog(@"tap");
            [self.recognitionRequest appendAudioPCMBuffer:buffer];
        }],

        [self.audioEngine prepare];
        [self.audioEngine startAndReturnError:nil];
    }
}

- (void) initAudioSession
{
//    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
//    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord
//                  withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker
//                  error:nil];
//    if (&AVAudioSessionModeSpokenAudio!=nil){
//        [audioSession setMode:AVAudioSessionModeSpokenAudio error:nil];
//    }
    //[audioSession setMode:AVAudioSessionModeMeasurement error:nil];
    //[audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
}

- (BOOL) permissionIsSet
{
    SFSpeechRecognizerAuthorizationStatus status = [SFSpeechRecognizer authorizationStatus];
    return status != SFSpeechRecognizerAuthorizationStatusNotDetermined && status != SFSpeechRecognizerAuthorizationStatusDenied;
}

- (void)recognition:(ISSpeechRecognition *)speechRecognition didGetRecognitionResult:(ISSpeechRecognitionResult *)result
{
    //NSLog(@"recog didGetRecognitionResult");
    NSMutableDictionary * resultDict = [[NSMutableDictionary alloc]init];
    [resultDict setValue:result.text forKey:@"transcript"];
    [resultDict setValue:[NSNumber numberWithBool:YES] forKey:@"final"];
    [resultDict setValue:[NSNumber numberWithFloat:result.confidence]forKey:@"confidence"];
    NSArray * alternatives = @[resultDict];
    NSArray * results = @[alternatives];
    [self sendResults:results];

}

-(void) recognition:(ISSpeechRecognition *)speechRecognition didFailWithError:(NSError *)error
{
    // iSpeech
    NSLog(@"recog fail: %@", error.localizedDescription);
    if (error.code == 28 || error.code == 23) {
        [self sendErrorWithMessage:[error localizedDescription] andCode:7];
    }
}

-(void) sendResults:(NSArray *) results
{
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"result" forKey:@"type"];
    [event setValue:nil forKey:@"emma"];
    [event setValue:nil forKey:@"interpretation"];
    [event setValue:results forKey:@"results"];

    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:YES];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
}

-(void) sendErrorWithMessage:(NSString *)errorMessage andCode:(NSInteger) code
{
    //NSLog(@"recog report error: %@", errorMessage);
    NSMutableDictionary * event = [[NSMutableDictionary alloc]init];
    [event setValue:@"error" forKey:@"type"];
    [event setValue:[NSNumber numberWithInteger:code] forKey:@"error"];
    [event setValue:errorMessage forKey:@"message"];
    self.pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsDictionary:event];
    [self.pluginResult setKeepCallbackAsBool:NO];
    [self.commandDelegate sendPluginResult:self.pluginResult callbackId:self.command.callbackId];
}

-(void) stop:(CDVInvokedUrlCommand*)command
{
    // called when user hits a button - this will also trigger last recognition and therefore stopAndRelease
    //NSLog(@"recog stop");
    [self.recognitionTask finish];
    //[self stopOrAbort];
}

-(void) abort:(CDVInvokedUrlCommand*)command
{
    //NSLog(@"recog abort");  //does this invoke stopAndRelease???
    if (NSClassFromString(@"SFSpeechRecognizer")) {
        if (self.recognitionTask!=nil){
            [self.recognitionTask cancel];
        }
    } else {
        [self.iSpeechRecognition cancel];
    }
//    [self stopOrAbort];
}

-(void) stopOrAbort
{
    //NSLog(@"recog stopOrAbort");
    if (NSClassFromString(@"SFSpeechRecognizer")) {
        if (self.audioEngine.isRunning) {
            [self.audioEngine stop];
            [self.recognitionRequest endAudio];
        }
    } else {
        [self.iSpeechRecognition cancel];
    }
}

-(void) stopAndRelease
{
    // called after last recognition or error
    NSLog(@"recog stopAndRelease");
    //NSLog(@"recog state: %ld", (long)self.recognitionTask.state);
    if (NSClassFromString(@"SFSpeechRecognizer")) {
        if (self.audioEngine!=nil && self.audioEngine.isRunning){
            [self.audioEngine stop];
            [self.audioEngine.inputNode removeTapOnBus:0];
        }
        if (self.recognitionRequest!=nil){
            [self.recognitionRequest endAudio];
        }
        self.recognitionRequest = nil;
        //self.recognitionTask = nil;            // maybe dont need to kill this
    }
}

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer
   availabilityDidChange:(BOOL)available{
    if (available){
        NSLog(@"recog availabile");
    }else{
        NSLog(@"recog no longer availabile");
    }
}

@end
