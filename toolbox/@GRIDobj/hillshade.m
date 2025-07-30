function OUT2 = hillshade(DEM,options)

%HILLSHADE Calculate hillshading from a digital elevation model
%
% Syntax
%    
%     H = hillshade(DEM)
%     H = hillshade(DEM,'pn','pv',...)
%
% Description
%
%     Hillshading is a very powerful tool for relief depiction.
%     hillshade calculates a shaded relief for a digital elevation model 
%     based on the angle between the surface and the incoming light beams.
%     If no output arguments are defined, the hillshade matrix will be
%     plotted with a gray colormap. The hillshading algorithm follows the
%     logarithmic approach to shaded relief representation of Katzil and
%     Doytsher (2003).
%
% Input
%
%     DEM       Digital elevation model (class: GRIDobj)
%
% Parameter name/value pairs
%
%     'azimuth'         azimuth angle, (default=315)
%     'altitude'        altitude angle, (default=60)
%     'exaggerate'      elevation exaggeration (default=1). Increase to
%                       pronounce elevation differences in flat terrain
%     'useblockproc'    true or {false}: use block processing 
%                       (see function blockproc)
%     'useparallel'     true or {false}: use parallel computing toolbox
%     'blocksize'       blocksize for blockproc (default: 5000)
%     'method'          'surfnorm' (default) or 'mdow'
%
%
% Output
%
%     H         shaded relief (ranges between 0 and 1)
%
%
% Example
%
%     DEM = GRIDobj('srtm_bigtujunga30m_utm11.tif');
%     hillshade(DEM)
% 
% References
%
%     Katzil, Y., Doytsher, Y. (2003): A logarithmic and sub-pixel approach
%     to shaded relief representation. Computers & Geosciences, 29,
%     1137-1142.
%
% See also: SURFNORM, IMAGESCHS
%
% Author: Wolfgang Schwanghart (schwangh[at]uni-potsdam.de)
% Date: 31. August, 2024

arguments
    DEM  GRIDobj
    options.azimuth (1,1) {mustBeNumeric,mustBeInRange(options.azimuth,0,360)} = 315
    options.altitude (1,1) {mustBeNumeric,mustBeInRange(options.altitude,0,90)} = 60
    options.exaggerate (1,1) {mustBeNumeric,mustBePositive} = 1
    options.useparallel (1,1) = true
    options.blocksize  (1,1) {mustBeNumeric,mustBePositive} = 2000
    options.useblockproc (1,1) = true
    options.method = 'default'
    options.uselibtt = true
end

% Preallocate output
OUT     = DEM;
% Cellsize
cs      = DEM.cellsize;
% Azimuth in degrees
azimuth = options.azimuth;
% Altitude in degrees
altitude = options.altitude;
% Exaggerate
exaggerate = options.exaggerate;

if options.uselibtt && haslibtopotoolbox && ...
        ismember(options.method,{'default','surfnorm'})
    % Use libtt
    if options.exaggerate ~= 1
        DEM.Z = DEM.Z*options.exaggerate;
    end
    % libtt requires radians 
    altitude = deg2rad(altitude);
    % azimuth is measured anticlockwise
    azimuth  = -90+azimuth;
    azimuth  = deg2rad(azimuth);
    % run mex function
    [OUT.Z, ~,~] = tt_hillshade(single(DEM.Z),azimuth,altitude,cs);

else

    method   = validatestring(options.method,{'default','surfnorm','mdow'});

    % Large matrix support. Break calculations in chunks using blockproc
    if numel(DEM.Z)>(10001*10001) && options.useblockproc
        blksiz = bestblk(size(DEM.Z),options.blocksize);
        padval = 'symmetric';
        Z      = DEM.Z;
        % The anonymous function must be defined as a variable: see bug 1157095
        fun   = @(x) hsfun(x,cs,azimuth,altitude,exaggerate,method);
        HS = blockproc(Z,blksiz,fun,...
            'BorderSize',[1 1],...
            'padmethod',padval,...
            'UseParallel',options.useparallel);
        OUT.Z = HS;
    else
        OUT.Z = hsfun(DEM.Z,cs,azimuth,altitude,exaggerate,method);
    end

end

OUT.name = 'hillshade';
OUT.zunit = '';

if nargout == 0
    OUT.Z = uint8(OUT.Z*255);
    imagesc(OUT);
    colormap(gray)
else
    OUT2 = OUT;
end

end
%% Subfunction
function H = hsfun(Z,cs,azimuth,altitude,exaggerate,method)

if isstruct(Z)
    Z = Z.data;    
end

switch method
    case {'default','surfnorm'}

        % correct azimuth so that angles go clockwise from top
        azid = azimuth-90;
        
        % use radians
        altsource = altitude/180*pi;
        azisource = azid/180*pi;
        
        % calculate solar vector
        [sx,sy,sz] = sph2cart(azisource,altsource,1);
        
        % calculate surface normals
        [Nx,Ny,Nz] = surfnorm(Z/cs*exaggerate);
        
        % calculate cos(angle)
        % H = [Nx(:) Ny(:) Nz(:)]*[sx;sy;sz];
        % % reshape
        % H = reshape(H,size(Nx));
        
        H = Nx*sx + Ny*sy + Nz*sz;
        
        % % usual GIS approach
        % H = acos(H);
        % % force H to range between 0 and 1
        % H = H-min(H(:));
        % H = H/max(H(:));

    case 'mdow'

        
        % correct azimuth so that angles go clockwise from top
        azid = [360 315 225 270] - 90;
        azisource = azid/180*pi;
        
        altsource = 30/180*pi;
        altsource = repmat(altsource,size(azisource));
        
        % calculate solar vector
        [sx,sy,sz] = sph2cart(azisource,altsource,1);
        
        % calculate surface normals
        [Nx,Ny,Nz] = surfnorm(Z/cs*exaggerate);
        
        
        H = bsxfun(@times,Nx(:),sx) + bsxfun(@times,Ny(:),sy) + bsxfun(@times,Nz(:),sz);
        H = max(H,0);
        H = sum(H,2)./3;
        H = reshape(H,size(Z));
end


end
