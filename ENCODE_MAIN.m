function ENCODE_MAIN()
%% IMAGE STEGANOGRAPHY - ENCODING MODULE
% This function encodes a text message into a set of images using 
% steganographic techniques. The message is hidden by modifying pixel
% values based on keys derived from a Google Drive URL.

    clc;
    close all;
    clear all;

    %% SECTION 1: Initialize and get user inputs
    fprintf('=== IMAGE STEGANOGRAPHY ENCODER ===\n');
    
    % Get URL from user and extract encryption keys
    url = getUserURL();
    keys = extractKeysFromURL(url);
    
    % Get message to encode
    message = getUserMessage();
    encodedMessage = encodeMessageToRGB(message);
    
    % Get image folder path
    imagePath = selectImageFolder();
    images = loadImages(imagePath);
    
    fprintf('Loaded %d images for encoding\n', length(images));
    
    %% SECTION 2: Prepare images and indices
    [originalIndices, modifiedIndices] = splitImageIndices(images, keys.imageSplit);
    
    % Initialize 4D image array (RGB + flag channel)
    images4D = initializeImageFlags(images);
    
    %% SECTION 3: Encode message into images
    fprintf('Starting encoding process...\n');
    encodingStats = encodeMessageIntoImages(images, images4D, encodedMessage, ...
                                          originalIndices, modifiedIndices, keys);
    
    %% SECTION 4: Save encoded images
    saveEncodedImages(images, imagePath);
    
    %% SECTION 5: Calculate and display statistics
    similarityIndex = calculateSimilarityIndex(images4D);
    displayEncodingResults(encodingStats, similarityIndex);
    
    msgbox('ENCODING DONE!', 'Success');
end

%% HELPER FUNCTIONS

function url = getUserURL()
    % Get URL input from user
    userInput = inputdlg('Enter Google Drive URL:', 'ENCODE - URL', [1 100]);
    url = userInput{1};
    
    if isempty(url)
        error('URL cannot be empty');
    end
end

function keys = extractKeysFromURL(url)
    % Extract encryption keys from Google Drive URL
    % Keys are derived from the folder ID after 'ers/'
    
    folderIdStart = strfind(url, 'ers/') + 4;
    if isempty(folderIdStart)
        error('Invalid Google Drive URL format');
    end
    
    keyString = url(folderIdStart:end);
    keyLength = length(keyString);
    
    if keyLength < 28
        error('URL too short to generate sufficient keys');
    end
    
    % Split key into 4 parts: 7-6-7-8 characters
    keys.originJump = keyString(1:7);           % Key for jumping between original images
    keys.pixelJump = keyString(8:13);           % Key for jumping pixel coordinates  
    keys.modifiedJump = keyString(14:20);       % Key for jumping between modified images
    keys.imageSplit = keyString(21:end);        % Key for selecting which images to modify
    
    % Convert to ASCII values for calculations
    keys.originJumpASCII = double(keys.originJump);
    keys.pixelJumpASCII = double(keys.pixelJump);
    keys.modifiedJumpASCII = double(keys.modifiedJump);
    keys.imageSplitASCII = double(keys.imageSplit);
end

function message = getUserMessage()
    % Get message input from user
    userInput = inputdlg('Enter Message (max 1500 characters):', ...
                        'ENCODE - Message', [30 100]);
    message = lower(userInput{1});
    
    if length(message) > 1500
        error('Message too long. Maximum 1500 characters allowed.');
    end
    
    % Add end-of-message marker
    message = [message, '§'];
end

function encodedMessage = encodeMessageToRGB(message)
    % Convert each character to RGB values for encoding
    messageLength = length(message);
    encodedMessage = zeros(messageLength, 3);
    
    for i = 1:messageLength
        encodedMessage(i, :) = encode_char(message(i));
    end
end

function imagePath = selectImageFolder()
    % Let user select folder containing images
    currentPath = pwd;
    imagePath = uigetdir(currentPath, 'Select folder containing images to encode');
    
    if imagePath == 0
        error('No folder selected');
    end
end

function images = loadImages(imagePath)
    % Load all images from selected folder
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
    % Split images into two groups: original (reference) and modified (encoded)
    numImages = length(images);
    halfSize = floor(numImages / 2);
    
    % Determine which images will be modified based on key
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
    % Add a 4th channel to track which pixels have been modified
    numImages = length(images);
    images4D = cell(numImages, 1);
    
    parfor i = 1:numImages
        imageSize = size(images{i});
        flagChannel = zeros(imageSize(1:2));
        
        images4D{i} = cat(3, images{i}, flagChannel);
    end
end

function stats = encodeMessageIntoImages(images, images4D, encodedMessage, ...
                                       originalIndices, modifiedIndices, keys)
    % Main encoding loop - hide message in image pixels
    
    messageLength = size(encodedMessage, 1);
    stats.processedPixels = 0;
    stats.modifiedImages = length(modifiedIndices);
    
    % Initialize indices and positions
    originalImageIdx = 1;
    modifiedImageIdx = 1;
    originalPixelPos = [1, 1];
    modifiedPixelPos = [1, 1];
    
    keyJumpIdx = 1;
    pixelJumpIdx = 1;
    
    % Process each character in the message
    for charIdx = 1:messageLength
        % Find next available pixel pair
        while images4D{modifiedIndices(modifiedImageIdx)}(modifiedPixelPos(1), modifiedPixelPos(2), 4) == 1
            [originalImageIdx, modifiedImageIdx, originalPixelPos, modifiedPixelPos, ...
             keyJumpIdx, pixelJumpIdx] = jumpToNextPixel(originalImageIdx, modifiedImageIdx, ...
                                                       originalPixelPos, modifiedPixelPos, ...
                                                       keyJumpIdx, pixelJumpIdx, ...
                                                       originalIndices, modifiedIndices, ...
                                                       images, keys);
        end
        
        % Encode character at current pixel position
        encodeCharacterAtPixel(images, originalIndices, modifiedIndices, ...
                             originalImageIdx, modifiedImageIdx, ...
                             originalPixelPos, modifiedPixelPos, ...
                             encodedMessage(charIdx, :));
        
        % Mark pixels as used
        images4D{originalIndices(originalImageIdx)}(originalPixelPos(1), originalPixelPos(2), 4) = 1;
        images4D{modifiedIndices(modifiedImageIdx)}(modifiedPixelPos(1), modifiedPixelPos(2), 4) = 1;
        
        stats.processedPixels = stats.processedPixels + 1;
        
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
    % Calculate next pixel positions based on keys
    
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

function encodeCharacterAtPixel(images, originalIndices, modifiedIndices, ...
                              origIdx, modIdx, origPos, modPos, rgbDelta)
    % Encode character by modifying pixel values
    
    % Get original pixel value
    originalPixel = images{originalIndices(origIdx)}(origPos(1), origPos(2), :);
    
    % Handle edge case for very bright pixels
    if any(originalPixel > 254)
        originalPixel(:) = 0;
    end
    
    % Copy original pixel to modified image
    images{modifiedIndices(modIdx)}(modPos(1), modPos(2), :) = originalPixel;
    
    % Add encoded RGB deltas
    images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 1) = ...
        images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 1) + rgbDelta(1);
    images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 2) = ...
        images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 2) + rgbDelta(2);
    images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 3) = ...
        images{modifiedIndices(modIdx)}(modPos(1), modPos(2), 3) + rgbDelta(3);
end

function saveEncodedImages(images, originalPath)
    % Save all encoded images to output folder
    [parentPath, ~, ~] = fileparts(originalPath);
    outputPath = fullfile(parentPath, 'Encoded Output Folder');
    
    if ~exist(outputPath, 'dir')
        mkdir(outputPath);
    end
    
    imageFiles = dir([originalPath, '/*']);
    imageFiles = imageFiles(~[imageFiles.isdir]);
    
    for i = 1:length(images)
        filename = fullfile(outputPath, imageFiles(i).name);
        rgbImage = images{i}(:, :, 1:3); % Remove 4th channel
        imwrite(rgbImage, filename, 'Mode', 'lossless');
    end
    
    fprintf('Encoded images saved to: %s\n', outputPath);
end

function similarityIndex = calculateSimilarityIndex(images4D)
    % Calculate similarity index for each image
    numImages = length(images4D);
    similarityIndex = zeros(numImages, 1);
    
    for i = 1:numImages
        modifiedPixels = sum(sum(images4D{i}(:, :, 4)));
        totalPixels = size(images4D{i}(:, :, 4), 1) * size(images4D{i}(:, :, 4), 2);
        similarityIndex(i) = (totalPixels - modifiedPixels) / totalPixels;
    end
end

function displayEncodingResults(stats, similarityIndex)
    % Display encoding statistics
    fprintf('\n=== ENCODING RESULTS ===\n');
    fprintf('Characters encoded: %d\n', stats.processedPixels);
    fprintf('Images modified: %d\n', stats.modifiedImages);
    fprintf('Average similarity index: %.4f\n', mean(similarityIndex));
    fprintf('Min similarity index: %.4f\n', min(similarityIndex));
    fprintf('Max similarity index: %.4f\n', max(similarityIndex));
end