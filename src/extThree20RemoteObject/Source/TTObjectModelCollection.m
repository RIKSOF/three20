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

#import "TTObjectModelCollection.h"
#import "TTObjectModel.h"

@implementation TTObjectModelCollection

@synthesize objects;

/**
 * We have received a response.
 */
-(void)requestDidFinishLoad:(TTURLRequest*)request {
    
    // Make sure the response is correct.
    id rootObject = nil;
    
    // Prepare the response object depending on remote document format.
    if ( documentFormat == DOCUMENT_FORMAT_JSON ) {
#ifdef EXT_REMOTE_JSON
        rootObject = ((TTURLJSONResponse *)request.response).rootObject;
#endif
    } else {
#ifdef EXT_REMOTE_XML  
        // This is an xml document.
        rootObject = ((TTURLXMLResponse *)request.response).rootObject;
        if ( rootObject != nil && [rootObject isKindOfClass:[GDataXMLDocument class]] ) {
            rootObject = ((GDataXMLDocument *)rootObject).rootElement;
            
            // If the root is not an array, its possible its children are.
            if ( ![rootObject isKindOfClass:[NSArray class]] ) { 
                rootObject = [((GDataXMLElement *)rootObject) children];
            }
        } else {
            rootObject = nil;
        }
#endif
    }
    
    // Is the response an array?
    if ( rootObject != nil && [rootObject isKindOfClass:[NSArray class]] ) {
        
        // Get the root feed.
        NSArray *feed = rootObject;
        
        //Initialize object
        [self loadWithArray:feed];
        
        // Call the parent as we are done.
        [super requestDidFinishLoad:request];
        
    } else {
        NSLog(@"Inavlid or unexpected response type. (%@)", [rootObject class]);
        [super requestDidCancelLoad:request];
    }
    
    // Show the response received.
    NSLog(@"response = %@", rootObject );
}

/**
 * Remove the passed object from server.
 */
-(void)removeObject:(TTObjectModel *)model {
    
    // Set up the URL.
    NSLog(@"Making request to delete URL: %@", url);
    
    TTURLRequest* request = [TTURLRequest requestWithURL:url delegate:self];
    
    // Set the HTTP Method.
    request.httpMethod =  httpMethod;
    
    // Set the values.
    [request.parameters setDictionary:parameters];
    
    // Right now, we are disabling cache.
    request.cachePolicy = TTURLRequestCachePolicyNoCache;
    request.cacheExpirationAge = TT_CACHE_EXPIRATION_AGE_NEVER;
    
    NSLog(@"request.parameters : %@", request.parameters);
    
    // Finally send the request.
    [request send];
    
    // Delete from list of objects.
    if ( model != nil ) {
        [objects removeObject:model];
    } else {
        [objects removeAllObjects];
    }
}

/**
 * Load with given data.
 */
-(void)loadWithArray:(NSArray *)data {
               
    if ( objects == nil || primaryKey == nil ) {
        objects = [[NSMutableArray alloc ]init];
    }
    
    // Read all the data and load to the collection's array.
    if ( documentFormat == DOCUMENT_FORMAT_JSON ) {
        
#ifdef EXT_REMOTE_JSON        
        for (NSDictionary *entry in data) {
            TTObjectModel *sp = [[objectClass alloc] init];
            sp.documentFormat = DOCUMENT_FORMAT_JSON;
            [sp decodeFromDocument:entry];
            
            // If objects have a concept of a primary key, then 
            // use that to create a predicate. This ensures that
            // we update the values for same primary key, instead of
            // adding a new instance.
            if ( primaryKey != nil ) {
                
                NSString *predicateString = [NSString stringWithFormat:@"%@ == %@", primaryKey, @"%@"];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateString, 
                                          [sp valueForKey:primaryKey]];
                
                NSArray *filteredArray = [objects filteredArrayUsingPredicate:predicate];
                
                // If we found the object, update it instead of adding a new object.
                if ([filteredArray count] > 0) {
                    sp = [filteredArray objectAtIndex:0];
                    [sp decodeFromDocument:entry];
                    
                    // Let everyone know this object is updated.
                    [self didUpdateObject:sp atIndexPath:nil];
                    
                } else {
                    [objects addObject: sp];
                    [self didInsertObject:sp atIndexPath:nil];
                }
            } else {
                [objects addObject: sp];
                [self didInsertObject:sp atIndexPath:nil];
            }
        }
#endif        
    } else {
#ifdef EXT_REMOTE_XML        
        for ( GDataXMLElement *xmlElement in data ) {
            TTObjectModel *sp = [[objectClass alloc] init];
            sp.documentFormat = DOCUMENT_FORMAT_XML;
            [sp decodeFromDocument:xmlElement];
            
            // If objects have a concept of a primary key, then 
            // use that to create a predicate. This ensures that
            // we update the values for same primary key, instead of
            // adding a new instance.
            if ( primaryKey != nil ) {
                
                NSString *predicateString = [NSString stringWithFormat:@"%@ == %@", primaryKey, @"%@"];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:predicateString, 
                                          [sp valueForKey:primaryKey]];

                NSArray *filteredArray = [objects filteredArrayUsingPredicate:predicate];
                
                // If we found the object, update it instead of adding a new object.
                if ([filteredArray count] > 0) {
                    sp = [filteredArray objectAtIndex:0];
                    [sp decodeFromDocument:xmlElement];
                    
                    // Let everyone know this object is updated.
                    [self didUpdateObject:sp atIndexPath:nil];
                    
                } else {
                    [objects addObject: sp];
                    [self didInsertObject:sp atIndexPath:nil];
                }
            } else {
                [objects addObject: sp];
                [self didInsertObject:sp atIndexPath:nil];
            }
        }
#endif
    }
}

#pragma mark - iCloud Integration

/**
 * Extension of this object on the cloud. By default we take the class name.
 */
- (NSString *)documentExtensionOnCloud {
    return NSStringFromClass(objectClass);  
}

- (void)syncDocumentsWithCloud {
    // Pause the query till we finish this notification processing.
    [iCloudQuery stopQuery];
    
    // This is the list of all objects that had a corresponding UIDocument.
    NSMutableArray *matchingObjects = [[NSMutableArray alloc] init];
    
    // Load all the results in to objects and add to list.
    for ( int i = 0; i < iCloudQuery.resultCount; i++ ) {
        NSMetadataItem *item = [iCloudQuery resultAtIndex:i];
        
        // Make sure the new files are downloaded.
        /*if ( [(NSNumber *)[item valueForAttribute:NSMetadataUbiquitousItemIsDownloadedKey] boolValue] ) */{
            // Name of document.
            NSString *docName = [item valueForAttribute:NSMetadataItemFSNameKey];
            BOOL found = NO;
            
            // See if this document is already loaded.
            for ( int j = 0; j < objects.count; j++ ) {
                TTObjectModel *obj = [objects objectAtIndex:j];
                NSString *objFileName = [NSString stringWithFormat:@"%@.%@", obj.iCloudDocument.localizedName,
                                         [self documentExtensionOnCloud]];
                
                if ( [objFileName isEqualToString:docName] ) {
                    found = YES;
                    [matchingObjects addObject:obj];
                    break;
                }
            }
            
            // If this is a new object, add it to the list.
            if ( !found ) {
                
                // URL of document.
                NSURL *docURL = [item valueForAttribute:NSMetadataItemURLKey];
                
                // New object for this document.
                TTObjectModel *sp = [[objectClass alloc] init];
                sp.documentFormat = documentFormat;
                sp.iCloudDocument = [[TTCloudDocument alloc] initWithFileURL:docURL];
                sp.iCloudDocument.object = sp;
                
                // Remember this as a matching object so that it is not deleted accidentally.
                [matchingObjects addObject:sp];
                
                // Number of pending open
                noOfPendingOpen++;
                
                // Open the document.
                [sp.iCloudDocument openWithCompletionHandler:^(BOOL success) {
                    if ( success ) {
                        [objects addObject: sp];
                        [self didInsertObject:sp atIndexPath:nil];
                        
                        // Register for updates on this object.
                        NSNotificationCenter *defaultCenter = [NSNotificationCenter defaultCenter];
                        [defaultCenter addObserver:self
                                          selector:@selector(iCloudDocumentStateChanged:)
                                              name:UIDocumentStateChangedNotification
                                            object:sp.iCloudDocument];
                    } else {
                        // Handle error.
                    }
                    
                    noOfPendingOpen--;
                    
                    // If all pending opens are completed, restart query.
                    if ( noOfPendingOpen == 0 ) {
                        [iCloudQuery startQuery];
                    }
                }];
            }
        }
    }
    
    // Detect if any deletions have occured and delete them from the objects list.
    for ( int i = objects.count - 1; i >=0 ; i-- ) {
        TTObjectModel *obj = [objects objectAtIndex:i];
        
        // Does this element exist in the matching objects array?
        if ( ![matchingObjects containsObject:obj] ) {
            // Remove this object from the list.
            [super didDeleteObject:obj atIndexPath:nil];
        }
    }
    
    // Resume query again if there are no pending opens.
    if ( noOfPendingOpen == 0 ) {
        [iCloudQuery startQuery];
    }
}

/**
 * Handle notifications.
 */
-(void)iCloudQueryDidFinishGathering:(NSNotification *)notification {
    [super iCloudQueryDidFinishGathering:notification];
    [self syncDocumentsWithCloud];
}

-(void)iCloudQueryDidReceiveUpdate:(NSNotification *)notification {
    [super iCloudQueryDidReceiveUpdate:notification];
    [self syncDocumentsWithCloud];
}

/**
 * Detect updates and update UI accordingly.
 */
-(void)iCloudDocumentStateChanged:(NSNotification *)notification {
    [super iCloudDocumentStateChanged:notification];
    
    TTCloudDocument *doc = notification.object;
    
    // Is the document state normal?
    if ( doc.documentState & UIDocumentStateNormal ) {
        // Update the list.
        [super didUpdateObject:doc.object atIndexPath:nil];
    }
}

/**
 * On the insert event, check if this list is cloud enabled. If it is,
 * make a new instance of the cloud document and upload this new object
 * there.
 */
- (void)didInsertObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
    [super didInsertObject:object atIndexPath:indexPath];
    
    // Is this list cloud enabled? Also make sure this object is not already
    // added.
    TTObjectModel *obj = object;
    
    if ( iCloudUrl != nil && obj.iCloudDocument == nil ) {
        NSString *fileName = [NSString stringWithFormat:@"%@.%@", [self getUniqueName],
                              [self documentExtensionOnCloud]];
        
        NSURL *docURL = [[iCloudUrl URLByAppendingPathComponent:@"Documents"] URLByAppendingPathComponent:
                         fileName];
        
        obj.iCloudDocument = [[TTCloudDocument alloc] initWithFileURL:docURL];
        obj.iCloudDocument.object = object;
        
        [obj.iCloudDocument saveToURL:[obj.iCloudDocument fileURL] 
                 forSaveOperation:UIDocumentSaveForCreating
                completionHandler:^(BOOL success) {
                    if ( success ) {
                        
                    } else {
                        // Handle error. Remote the object from list?
                    }
        }];
    }
}

/**
 * On the update event, check if this list is cloud enabled. If it is,
 * make a new instance of the cloud document and upload this new object
 * there.
 */
- (void)didUpdateObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
    [super didUpdateObject:object atIndexPath:indexPath];

    TTObjectModel *obj = object;
    
    // Is this list cloud enabled?
    if ( obj.iCloudDocument != nil && 
         !( obj.iCloudDocument.documentState & UIDocumentStateEditingDisabled ) ) {
        [obj.iCloudDocument updateChangeCount:UIDocumentChangeDone];
    }
}

/**
 * On the delete event, check if this list is cloud enabled. If it is,
 * delete the document.
 */
- (void)didDeleteObject:(id)object atIndexPath:(NSIndexPath *)indexPath {
    [super didDeleteObject:object atIndexPath:indexPath];
    
    TTObjectModel *obj = object;
    
    if ( obj.iCloudDocument != nil && 
        !( obj.iCloudDocument.documentState & UIDocumentStateEditingDisabled ) ) {
        NSFileManager *defaultManager = [NSFileManager defaultManager];
        
        // Delete the object from cloud as well.
        NSError *error;
        [defaultManager removeItemAtURL:obj.iCloudDocument.fileURL error:&error];
    }
}
 
@end
