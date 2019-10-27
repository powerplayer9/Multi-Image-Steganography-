clc;
close all;
clear all;

%% URL read & get key data

User_input_URL = inputdlg('Enter URL:',...
             'ENCODE - URL', [1 100]);

         URL = User_input_URL{1};
%URL = 'https://drive.google.com/drive/u/0/folders/0B9pIMjMgQ6y4WFVtNllvYTNLOEU';
size_URL = size(URL,2);


k = strfind(URL,'ers/');
k = k + 4;

Key_main = URL(k:size_URL);
size_keymain = size(Key_main,2);

% 28char key -> 7-6-7-8
% 7 - key for jumping original image
% 6 - key for jumping pixel coordinates
% 7 - key for jumping modifined image
% 8 - key to jump & select original & modified image
Key_origin_jump = Key_main(1 : 7);
Key_pixel_jump = Key_main(8 : 13);
Key_modified_jump = Key_main(14 : 20);
Key_image_split = Key_main(21 : size_keymain);

size_origin_jump = size(Key_origin_jump);
size_pixel_jump = size(Key_pixel_jump);
size_modified_jump = size(Key_modified_jump);
size_image_split = size(Key_image_split);

%% Get Message & encode

User_input = inputdlg('Enter Message (1500 char):',...
             'ENCODE - Message', [30 100]);
         
msg_1 = lower(User_input{1});
end_of_msg = '§';
msg = strcat(msg_1,end_of_msg);
size_msg = size(msg);

parfor i = 1 : size_msg(2)
    [msg_en(i,:)] = encode_char(msg(i)); % Encoded message variable
end


%% Get file Path
%Parent_path = 'E:\Education\ANU\ENGN6528- Comp Vision\Project\Code';
Parent_path = pwd;
PathName = uigetdir(Parent_path,'Select the folder');

file3 = '*';

train_filenames3 = dir([PathName '/' file3]);    % return a structure with filenames


%% Remove '.' & '..' hidden directory files

while (train_filenames3(1).isdir == 1)
    train_filenames3(1) = [];
end

size_data = length(train_filenames3);

%%

parfor i = 1 : size_data
    filename = [train_filenames3(i).folder '\' train_filenames3(i).name];   % filename in the list
    Img{i} = imread(filename);
end

%save (' imageload.mat','Img');


%% Key data to numbers
% ASCII decode

Ascii_origin_jump = double(Key_origin_jump);
Ascii_pixel_jump = double(Key_pixel_jump);
Ascii_modified_jump = double(Key_modified_jump);
Ascii_image_split = double(Key_image_split);

%% Find original & modify image index in full image set data
% To split Image index to image that will be modified and not
if (rem(size_data,2) == 0)
    size_halfdata = size_data / 2;
else
    size_halfdata = (size_data-1) / 2;
end

k = 1;
j = 1;
img_index_Mod = 0;
n = 1;
%for i = 1 : size_halfdata
while n <= size_halfdata
    
    k = k + Ascii_image_split(j);
    
    while k > (2 * size_halfdata)
        diff = k - (2 * size_halfdata);
        k = diff;
        if k <= 0
            break;
        end
    end
    
    if (img_index_Mod(:) ~= k)
        if (k > 0)
            img_index_Mod(n) = k ;
            n = n+1;
        end
    end
    
    j = j+1;
    if j > size_image_split
        j = 1;
    end
    
end

img_index_Mod = sort (img_index_Mod);

n = 1;
for i = 1 : (2 * size_halfdata)
    if i ~= img_index_Mod(:)
        img_index_Ori(n) = i;
        n = n + 1;
    end
end


%% Change mod_img pix values
% To encode the image with the message
ind_ori = 1; %Index of original
ind_mod = 1; %Index of modified
ind_cood_ori = [1 1]; %coordinate index of original
ind_cood_mod = [1 1]; %coordinate index of modified

i_Done = [0 0 0 0 0 0];
i_D_count = 1;
ind_img_jump = 1;
ind_pixel_jump = 1;

% Flag for checking modification
parfor i = 1 : size_data
    size_dume_image = size(Img{i});
    z = zeros (size_dume_image(1:2));
    Img_4d{i}(:,:,:) = Img{i};
    Img_4d{i}(:,:,4) = z;
    
end

%Encoding of image
while i_D_count <= size_msg(2)
    
    
    if Img_4d{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),4) ~= 1
        
        i_Done(i_D_count,1:6) = [ img_index_Ori(ind_ori) ind_cood_ori(1) ind_cood_ori(2) ...
            img_index_Mod(ind_mod) ind_cood_mod(1) ind_cood_mod(2)];
        
        %Access pixel original img
        pix_val = Img{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),:);
        
        %If original pixel vaiue is 245+
        if pix_val(:,:,1) > 254 || pix_val(:,:,2) > 254 || pix_val(:,:,3) > 254
            
            pix_val(:,:,1) = 0;
            pix_val(:,:,2) = 0;
            pix_val(:,:,3) = 0;
            
        end
               
        %copy mod pixel value to dummy
        pix_val_2 = Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),:);
        
        %copy original pixel value to target image
        Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),:) = pix_val;
        
        
        
        R = msg_en(i_D_count,1);
        G = msg_en(i_D_count,2);
        B = msg_en(i_D_count,3);
        
        
        %pre-mod values
        i_Done(i_D_count,7:9) = [ ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),1) ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),2) ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),3) ];
        
        %R value change
        Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),1) = ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),1) + R;
        %G value change
        Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),2) = ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),2) + G;
        %B value change
        Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),3) = ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),3) + B;
        
        
        %Modified values
        i_Done(i_D_count,10:12) = [ ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),1) ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),2) ...
            Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),3) ];
        
        %original valueas
        i_Done(i_D_count,13:15) = [ ...
            Img{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),1) ...
            Img{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),2) ...
            Img{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),3) ];
        
        Img_4d{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),4) = 1;
        Img_4d{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),4) = 1;
        
        i_D_count = i_D_count + 1;
        
    end
    
    %Image jump control
    ind_ori = ind_ori + Ascii_origin_jump(ind_img_jump);
    while ind_ori > (size_halfdata)
        diff = ind_ori - (size_halfdata);
        ind_ori = diff;
        if ind_ori <= 0
            break;
        end
    end
    
    ind_mod = ind_mod + Ascii_origin_jump(ind_img_jump);
    while ind_mod > (size_halfdata)
        diff = ind_mod - (size_halfdata);
        ind_mod = diff;
        if ind_mod <= 0
            break;
        end
    end
    
    %     ind_cood_ori = [1 1]; %coordinate index of original
    %     ind_cood_mod = [1 1]; %coordinate index of modified
    
    ind_cood_ori(1) = ind_cood_ori(1) + Ascii_pixel_jump(ind_pixel_jump);
    ind_cood_mod(1) = ind_cood_mod(1) + Ascii_pixel_jump(ind_pixel_jump);
    
    %if original pixel is out of bound for mod image.
    %     if
    
    %Pixel jump control
    
    size_ori_curr_image = size(Img{img_index_Ori(ind_ori)});
    while ind_cood_ori (1) > (size_ori_curr_image (1))
        diff = ind_cood_ori(1) - (size_ori_curr_image(1));
        ind_cood_ori(2) = ind_cood_ori(2) + 1;
        ind_cood_ori(1) = diff;
        if ind_cood_ori(1) <= 0
            break;
        end
    end
    
    size_mod_curr_image = size(Img{img_index_Mod(ind_mod)});
    while ind_cood_mod(1) > (size_mod_curr_image (1))
        diff = ind_cood_mod(1) - (size_mod_curr_image(1));
        ind_cood_mod(2) = ind_cood_mod(2) + 1;
        ind_cood_mod(1) = diff;
        if ind_cood_mod(1) <= 0
            break;
        end
    end
    
    
    ind_img_jump = ind_img_jump + 1;
    ind_pixel_jump = ind_pixel_jump + 1;
    
    if ind_img_jump == size_origin_jump(2)
        ind_img_jump = 1;
    end
    
    if ind_pixel_jump == size_pixel_jump(2)
        ind_pixel_jump = 1;
    end
    
end

%% Save the modified images

mkdir (Parent_path,'Encoded Output Folder');
savepath = 'Encoded Output Folder/';


for i = 1 : size_data
    filename = [savepath train_filenames3(i).name];   % filename in the list
    Image_back_to_3D = Img{i}(:,:,1:3);
    imwrite(Image_back_to_3D,filename, 'Mode', 'lossless');
end

h=msgbox('ENCODING DONE!')

%% Similarity Index
% Comparing similarity index
%Computationally Heavy;
%PLEASE do individually for all images to check similarity
%Ie change i valus manually.
 for i  = 1 : size_data
Number_of_pixel_changes = sum(sum(Img_4d{i}(:,:,4)));
Total_pixel = size(Img_4d{i}(:,:,4),1) * size(Img_4d{i}(:,:,4),2);
Similarity_index (i) = (Total_pixel - Number_of_pixel_changes) / Total_pixel;
 end

% % %  USE UNDER OWN TIME- This function is more accurate but 
% % %  Is too process exhaustive. So will consume a lot of time.
% % % %  for i = 1 : size_data
% % % %      x = ssim(Img{i}(:,:,1:3), Img_4d{i}(:,:,1:3));
% % % %  end
 
% plot(x);