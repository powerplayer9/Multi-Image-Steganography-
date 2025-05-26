function DECODE_MAIN()
%% IMAGE STEGANOGRAPHY - DECODING MODULE
% This function decodes a hidden text message from a set of encoded images
% using the same keys derived from a Google Drive URL that was used for encoding.

    clc;
    close all;
    clear all;

    %% SECTION 1: Initialize and get user inputs
    fprintf('=== IMAGE STEGANOGRAPHY DECODER ===\n');
    
    % Get URL and extract decryption keys (same as encoding)
    url = getUserURL();
    keys = extractKeysFromURL(url);
    
    % Get encoded images folder path
    imagePath = selectEncodedImageFolder();
    images = loadImages(imagePath);
    
    fprintf('Loaded %d encoded images for decoding\n', length(images));
    
    %% SECTION 2: Prepare images and indices
    [originalIndices, modifiedIndices] = splitImageIndices(images, keys.imageSplit);
    
    % Initialize 4D image array (RGB + flag channel)
    images4D = initializeImageFlags(images);
    
    %% SECTION 3: Decode message from images
    fprintf('Starting decoding process...\n');
    [decodedMessage, decodingStats] = decodeMessageFromImages(images, images4D, ...
                                                            originalIndices, modifiedIndices, keys);
    
    %% SECTION 4: Process and display results
    finalMessage = processDecodedMessage(decodedMessage);
    displayDecodingResults(finalMessage, decodingStats);
    
    % Show message to user
    msgbox(finalMessage, 'Decoded Message');
end

%% HELPER FUNCTIONS

function url = getUserURL()
    % Get URL input from user
    userInput = inputdlg('Enter Google Drive URL:', 'DECODE - URL', [1 100]);
    url = userInput{1};
    
    if isempty(url)
        error('URL cannot be empty');
    end
end

function keys = extractKeysFromURL(url)
    % Extract decryption keys from Google Drive URL
    % Keys must match those used during encoding
    
    folderIdStart = strfind(url, 'ers/') + 4;
    if isempty(folderIdStart)
        error('Invalid Google Drive URL format');
    end
    
    keyString = url(folderIdStart:end);
    keyLength = length(keyString);
    
    if keyLength < 28
        error('URL too short to generate sufficient keys');
    end
    
    % Split key into 4 parts: 7-6-7-8 characters (same as encoding)
    keys.originJump = keyString(1:7);
    keys.pixelJump = keyString(8:13);
    keys.modifiedJump = keyString(14:20);
    keys.imageSplit = keyString(21:end);
    
    % Convert to ASCII values for calculations
    keys.originJumpASCII = double(keys.originJump);
    keys.pixelJumpASCII = double(keys.pixelJump);
    keys.modifiedJumpASCII = double(keys.modifiedJump);
    keys.imageSplitASCII = double(keys.imageSplit);
end

function imagePath = selectEncodedImageFolder()
    % Let user select folder containing encoded images
    currentPath = pwd;
    imagePath = uigetdir(currentPath, 'Select folder containing encoded images');
    
    if imagePath == 0
        error('No folder selected');
    end
end

function images = loadImages(imagePath)
    % Load all encoded images from selected folder
    imageFiles = dir([imagePath, '/*']);
    
    % Remove directory entries
    imageFiles = imageFiles(~[imageFiles.isdir]);
    
    if isempty(imageFiles)
        error('No image files found in selected folder');
    end
    
    numImages = length(imageFiles);
    images = cell(numImages, 1);
    
    % Load images in parallel for efficiency
    parfor i = 1:numImages
        filename = fullfile(imageFiles(i).folder, imageFiles(i).name);
        images{i} = imread(filename);
    end
end

function [originalIndices, modifiedIndices] = splitImageIndices(images, imageSplitKey)
    % Split images into original and modified groups (same logic as encoding)
    numImages = length(images);
    halfSize = floor(numImages / 2);
    
    % Determine which images were modified based on key
    modifiedIndices = [];
    keyASCII = double(imageSplitKey);
    keyLength = length(keyASCII);
    
    currentIndex = 1;
    keyPosition = 1;
    
    while length(modifiedIndices) < halfSize
        currentIndex = currentIndex + keyASCII(keyPosition);
        
        % Wrap around if index exceeds available images
        while currentIndex > (2 * halfSize)
            currentIndex = currentIndex - (2 * halfSize);
        end
        
        if currentIndex > 0 && ~ismember(currentIndex, modifiedIndices)
            modifiedIndices(end + 1) = currentIndex;
        end
        
        keyPosition = keyPosition + 1;
        if keyPosition > keyLength
            keyPosition = 1;
        end
    end
    
    modifiedIndices = sort(modifiedIndices);
    
    % Remaining images are originals
    allIndices = 1:(2 * halfSize);
    originalIndices = setdiff(allIndices, modifiedIndices);
end

function images4D = initializeImageFlags(images)
    % Add a 4th channel to track which pixels have been processed
    numImages = length(images);
    images4D = cell(numImages, 1);
    
    parfor i = 1:numImages
        imageSize = size(images{i});
        flagChannel = zeros(imageSize(1:2));
        
        images4D{i} = cat(3, images{i}, flagChannel);
    end
end

function [decodedMessage, stats] = decodeMessageFromImages(images, images4D, ...
                                                         originalIndices, modifiedIndices, keys)
    % Main decoding loop - extract hidden message from image pixels
    
    decodedMessage = '';
    endMarker = '§';
    stats.processedPixels = 0;
    stats.decodedImages = length(modifiedIndices);
    
    % Initialize indices and positions (same as encoding)
    originalImageIdx = 1;
    modifiedImageIdx = 1;
    originalPixelPos = [1, 1];
    modifiedPixelPos = [1, 1];
    
    keyJumpIdx = 1;
    pixelJumpIdx = 1;
    
    % Decode characters until end marker is found
    while true
        % Find next available pixel pair
        while images4D{modifiedIndices(modifiedImageIdx)}(modifiedPixelPos(1), modifiedPixelPos(2), 4) == 1
            [originalImageIdx, modifiedImageIdx, originalPixelPos, modifiedPixelPos, ...
             keyJumpIdx, pixelJumpIdx] = jumpToNextPixel(originalImageIdx, modifiedImageIdx, ...
                                                       originalPixelPos, modifiedPixelPos, ...
                                                       keyJumpIdx, pixelJumpIdx, ...
                                                       originalIndices, modifiedIndices, ...
                                                       images, keys);
        end
        
        % Decode character at current pixel position
        decodedChar = decodeCharacterAtPixel(images, originalIndices, modifiedIndices, ...
                                           originalImageIdx, modifiedImageIdx, ...
                                           originalPixelPos, modifiedPixelPos);
        
        % Mark pixels as processed
        images4D{originalIndices(originalImageIdx)}(originalPixelPos(1), originalPixelPos(2), 4) = 1;
        images4D{modifiedIndices(modifiedImageIdx)}(modifiedPixelPos(1), modifiedPixelPos(2), 4) = 1;
        
        decodedMessage = [decodedMessage, decodedChar];
        stats.processedPixels = stats.processedPixels + 1;
        
        % Check for end of message
        if strcmp(decodedChar, endMarker)
            break;
        end
        
        % Move to next pixel position
        [originalImageIdx, modifiedImageIdx, originalPixelPos, modifiedPixelPos, ...
         keyJumpIdx, pixelJumpIdx] = jumpToNextPixel(originalImageIdx, modifiedImageIdx, ...
                                                   originalPixelPos, modifiedPixelPos, ...
                                                   keyJumpIdx, pixelJumpIdx, ...
                                                   originalIndices, modifiedIndices, ...
                                                   images, keys);
    end
end

function [origIdx, modIdx, origPos, modPos, keyIdx, pixelIdx] = ...
         jumpToNextPixel(origIdx, modIdx, origPos, modPos, keyIdx, pixelIdx, ...
                        originalIndices, modifiedIndices, images, keys)
    % Calculate next pixel positions based on keys (same logic as encoding)
    
    halfSize = length(originalIndices);
    
    % Jump to next images
    origIdx = origIdx + keys.originJumpASCII(keyIdx);
    modIdx = modIdx + keys.originJumpASCII(keyIdx);
    
    % Handle wraparound for image indices
    origIdx = wrapIndex(origIdx, halfSize);
    modIdx = wrapIndex(modIdx, halfSize);
    
    % Jump to next pixel coordinates
    origPos(1) = origPos(1) + keys.pixelJumpASCII(pixelIdx);
    modPos(1) = modPos(1) + keys.pixelJumpASCII(pixelIdx);
    
    % Handle wraparound for pixel coordinates
    origPos = wrapPixelCoordinates(origPos, size(images{originalIndices(origIdx)}));
    modPos = wrapPixelCoordinates(modPos, size(images{modifiedIndices(modIdx)}));
    
    % Update key indices
    keyIdx = keyIdx + 1;
    pixelIdx = pixelIdx + 1;
    
    if keyIdx > length(keys.originJumpASCII)
        keyIdx = 1;
    end
    
    if pixelIdx > length(keys.pixelJumpASCII)
        pixelIdx = 1;
    end
end

function wrappedIndex = wrapIndex(index, maxValue)
    % Wrap index within valid range
    while index > maxValue
        index = index - maxValue;
    end
    if index <= 0
        index = 1;
    end
    wrappedIndex = index;
end

function wrappedPos = wrapPixelCoordinates(pos, imageSize)
    % Wrap pixel coordinates within image bounds
    while pos(1) > imageSize(1)
        pos(1) = pos(1) - imageSize(1);
        pos(2) = pos(2) + 1;
    end
    
    if pos(1) <= 0
        pos(1) = 1;
    end
    
    if pos(2) > imageSize(2)
        pos(2) = imageSize(2);
    end
    
    wrappedPos = pos;
end

function decodedChar = decodeCharacterAtPixel(images, originalIndices, modifiedIndices, ...
                                            origIdx, modIdx, origPos, modPos)
    % Decode character by analyzing pixel value differences
    
    % Get original pixel value
    originalPixel = images{originalIndices(origIdx)}(origPos(1), origPos(2), :);
    
    % Handle edge case for very bright pixels (same as encoding)
    if any(originalPixel > 254)
        originalPixel(:) = 0;
    end
    
    % Get modified pixel value
    modifiedPixel = images{modifiedIndices(modIdx)}(modPos(1), modPos(2), :);
    
    % Calculate RGB differences
    rDiff = abs(double(modifiedPixel(1)) - double(originalPixel(1)));
    gDiff = abs(double(modifiedPixel(2)) - double(originalPixel(2)));
    bDiff = abs(double(modifiedPixel(3)) - double(originalPixel(3)));
    
    % Decode character from RGB differences
    decodedChar = decode_char(rDiff, gDiff, bDiff);
end

function finalMessage = processDecodedMessage(rawMessage)
    % Process decoded message by replacing special characters
    
    % Replace space encoding character with actual spaces
    processedMessage = strrep(rawMessage, '¼', ' ');
    
    % Replace end marker with readable text
    finalMessage = strrep(processedMessage, '§', '<end of message>');
end

function displayDecodingResults(message, stats)
    % Display decoding statistics and results
    fprintf('\n=== DECODING RESULTS ===\n');
    fprintf('Characters decoded: %d\n', stats.processedPixels);
    fprintf('Images processed: %d\n', stats.decodedImages);
    fprintf('Decoded message: %s\n', message);
end