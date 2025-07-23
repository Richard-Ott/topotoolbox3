function [Z,R,wf] = createRasterFromFile(filename,options)

%CREATERASTERFROMFILE Creates a grid from a file
%
% Syntax
%
%     [Z,R,wf] = createRasterFromFile(filename,options)
%
% Description
%
%

arguments
    filename 
    options.OutputType = 'single'
    options.Bands = 1
    options.CoordinateSystemType = 'auto'
end

% Read raster using readgeoraster (if mapping toolbox available)
if license('test','MAP_Toolbox')
    [Z,R] = readgeoraster(filename,...
        'OutputType',options.OutputType,...
        'Bands',options.Bands,...
        'CoordinateSystemType',options.CoordinateSystemType);
    
    if isempty(R)
        error("TopoToolbox:createRasterFromFile", ...
            "The returned referencing matrix is empty. This is likely due \n" + ...
            "to an invalid geometry of the raster, e.g. extents beyond \n" + ...
            "the valid data range of latitudes and longitudes.")
    end

    wf = worldFileMatrix(R);

    % handle nans
    try
        tiffinfo = imfinfo(filename);
        if isfield(tiffinfo,'GDAL_NODATA')
            nodata_val = str2double(tiffinfo.GDAL_NODATA);
            Z(Z==nodata_val) = nan;
        end
    catch
        % do nothing
    end


    % [~,~,ext] = fileparts(filename);
    % switch lower(ext)
    %     case {'.tif','.tiff'}
    %         in = geotiffinfo(filename);
    %         try
    %             GeoKeyDirTag = in.GeoTIFFTags.GeoKeyDirectoryTag;
    %         catch
    %             GeoKeyDirTag = [];
    %         end
    %     otherwise
    %         GeoKeyDirTag = [];
    % end

else

    % Use imread and try to read the world file if mapping TopoToolbox
    % is not available.
    [folder,file,ext] = fileparts(filename);

    switch lower(ext)
        case {'.txt','.asc'}
            [Z,R,wf] = createRasterFromASCIIGrid(filename,...
                'OutputType',options.OutputType);
        otherwise
            switch ext
                case '.tif'
                    worldfileext = '.tfw';
                case '.jpg'
                    worldfileext = '.jgw';
                case '.gif'
                    worldfileext = '.gfw';
                case '.png'
                    worldfileext = '.pgw';
            end

            Z  = imread(filename);
            R  = [];
            Z  = cast(Z,options.OutputType);

            % Try to read world file
            try
                wf = readmatrix(fullfile(folder,file,worldfileext),...
                    'FileType','text');
                wf = reshape(wf,2,3);
            catch
                error('TopoToolbox:Import:Format',...
                    ['Mapping Toolbox not available. The raster with\n' ...
                    'the extension ' ext ' should have an accompanying\n' ...
                    'worldfile. Typically, the world file will have the\n' ...
                    'extension ' worldfileext '. If a world file is not\n' ...
                    'available, check other options to construct a GRIDobj.'])
            end
            
    end

end

