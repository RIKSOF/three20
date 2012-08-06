//
// Copyright 2012 RIKSOF
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import "TTCloudDocument.h"
#import "TTObjectModel.h"

@implementation TTCloudDocument
@synthesize object;

#pragma mark - Sending Data

/**
 * Encode the document and send it to iCloud.
 */
-(id)contentsForType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    // Prepare data for sending.
    NSData *data = [object toDocumentWithRoot:@"root"];
    return data;
}

#pragma mark - Receiving Data

/**
 * Decode the document and receive it from iCloud.
 */
-(BOOL)loadFromContents:(id)contents ofType:(NSString *)typeName error:(NSError *__autoreleasing *)outError {
    
    // Assume success unless proven wrong.
    BOOL status = YES;
    
#ifdef EXT_REMOTE_JSON
    if ( object.documentFormat == DOCUMENT_FORMAT_JSON ) {
        SBJsonParser *doc = [[SBJsonParser alloc] init];
        id rootElement = [doc objectWithData:contents];
    
        // If there was no error.
        if ( doc.error == nil ) {
            [object decodeFromDocument:rootElement];
        } else {
            NSLog(@"Error while reading data from iCloud: %@", doc.error);
            status = NO;
        }
    }
#endif
    
#ifdef EXT_REMOTE_XML
    if ( object.documentFormat == DOCUMENT_FORMAT_XML ) {
        NSError *error;
        GDataXMLDocument *doc = [[GDataXMLDocument alloc] initWithData:contents 
                                                               options:0 error:&error];
        
        // If there was no error.
        if ( error == nil ) {
            [object decodeFromDocument:doc.rootElement];
        } else {
            NSLog(@"Error while reading data from file: %@", [error localizedDescription]);
            NSString *errorStr = [[NSString alloc] initWithData:contents 
                                                       encoding:NSASCIIStringEncoding];
            NSLog(@"Error occured on following feed: %@", errorStr);
            status = NO;
        }
    }
#endif
    
    return status;
}

@end
