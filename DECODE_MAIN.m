clc;
close all;
clear all;


%% URL read & get key data

User_input_URL = inputdlg('Enter URL:',...
             'DECODE - URL', [1 100]);

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


%% File Path
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




%% Key data to numbers
% ASCII decode

Ascii_origin_jump = double(Key_origin_jump);
Ascii_pixel_jump = double(Key_pixel_jump);
Ascii_modified_jump = double(Key_modified_jump);
Ascii_image_split = double(Key_image_split);

%% Find original & modify image index in full image set data
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


%% Find mod_img pix values
%Finding changes in pixel & retriving the characters.


ind_ori = 1; %Index of original image
ind_mod = 1; %Index of modified image
ind_cood_ori = [1 1]; %coordinate index of original
ind_cood_mod = [1 1]; %coordinate index of modified

i_Done = [0 0 0 0 0 0];
i_D_count = 1;
ind_img_jump = 1;
ind_pixel_jump = 1;

end_of_msg = '§';

% Flag for checking modification
for i = 1 : size_data
    size_dume_image = size(Img{i});
    z = zeros (size_dume_image(1:2));
    Img_4d{i}(:,:,:) = Img{i};
    Img_4d{i}(:,:,4) = z;
    
end

char_de = 'a';
msg_de = '';

%Encoding of image
while 1
    
    
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
        
        %Difference
        R = abs(Img{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),1) ...
            - Img{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),1));
        G = abs(pix_val_2(:,:,2) - pix_val(:,:,2));
        B = abs(pix_val_2(:,:,3) - pix_val(:,:,3));
        
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
        
        %Difference
        i_Done(i_D_count,7:9) = [R G B ];
        
        char_de = decode_char (R,G,B);
        msg_de = strcat(msg_de,char_de);
        
        Img_4d{img_index_Ori(ind_ori)}(ind_cood_ori(1), ind_cood_ori(2),4) = 1;
        Img_4d{img_index_Mod(ind_mod)}(ind_cood_mod(1), ind_cood_mod(2),4) = 1;
        
        i_D_count = i_D_count + 1;
        
    end
    
    
    if strcmp(char_de,end_of_msg) == 1
        break;
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
    
    ind_cood_ori(1) = ind_cood_ori(1) + Ascii_pixel_jump(ind_pixel_jump);
    ind_cood_mod(1) = ind_cood_mod(1) + Ascii_pixel_jump(ind_pixel_jump);
    
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

%% Remove message of extra char & display the message

op_1 = replace(msg_de,'¼',' ');
op_2 = replace(op_1,'§','<end of message>');

%Display output
h=msgbox(op_2);



