function [node, element, force, BC, E, A, alpha, T] = processFile(filename)
% PROCESSFILE Parse and validate the legacy 2D truss TXT format.
% Sections may appear in any order. Node/element IDs must be sequential
% from 1 because solver data structures use those IDs as MATLAB indices.
% A missing or blank prescribed displacement means a free DOF (NaN).

    fid = fopen(filename, 'rt');
    if fid < 0
        error('Truss:InputError', 'Cannot open input file: %s', char(filename));
    end
    fileCloser = onCleanup(@() fclose(fid)); %#ok<NASGU>

    node = zeros(0, 2);
    element = zeros(0, 2);
    forceRows = cell(0, 1);
    bcRows = cell(0, 1);
    section = '';
    E = NaN; A = NaN; alpha = 0; T = 0;
    lineNumber = 0;

    while true
        raw = fgetl(fid);
        if ~ischar(raw), break; end
        lineNumber = lineNumber + 1;
        line = strtrim(raw);
        if isempty(line) || line(1) == '%', continue; end

        if line(1) == '#'
            switch lower(line)
                case {'#node', '#element', '#force', '#boundry_condition', '#boundary_condition', '#metadata'}
                    section = lower(line);
                otherwise
                    error('Truss:InputError', 'Unknown section "%s" at line %d.', line, lineNumber);
            end
            continue;
        end
        if isempty(section)
            error('Truss:InputError', 'Data before the first section, line %d.', lineNumber);
        end

        parts = strsplit(line, ',', 'CollapseDelimiters', false);
        parts = cellfun(@strtrim, parts, 'UniformOutput', false);
        switch section
            case '#node'
                requireFields(parts, 3, lineNumber);
                id = parseId(parts{1}, 'n', lineNumber);
                if id ~= size(node, 1) + 1
                    error('Truss:InputError', 'Node IDs must be consecutive and ordered (line %d).', lineNumber);
                end
                node(end+1,:) = [parseNumber(parts{2}, lineNumber), parseNumber(parts{3}, lineNumber)]; %#ok<AGROW>
            case '#element'
                requireFields(parts, 3, lineNumber);
                id = parseId(parts{1}, 'e', lineNumber);
                if id ~= size(element, 1) + 1
                    error('Truss:InputError', 'Element IDs must be consecutive and ordered (line %d).', lineNumber);
                end
                ni = parsePositiveInteger(parts{2}, lineNumber);
                nj = parsePositiveInteger(parts{3}, lineNumber);
                if ni == nj
                    error('Truss:InputError', 'Element e%d connects a node to itself (line %d).', id, lineNumber);
                end
                element(end+1,:) = [ni, nj]; %#ok<AGROW>
            case '#force'
                requireFields(parts, 3, lineNumber);
                forceRows{end+1,1} = {parts, lineNumber}; %#ok<AGROW>
            case {'#boundry_condition', '#boundary_condition'}
                if numel(parts) < 2 || numel(parts) > 3
                    error('Truss:InputError', 'Invalid boundary condition at line %d.', lineNumber);
                end
                bcRows{end+1,1} = {parts, lineNumber}; %#ok<AGROW>
            case '#metadata'
                requireFields(parts, 2, lineNumber);
                value = parseNumber(parts{2}, lineNumber);
                switch parts{1}
                    case 'E', E = value;
                    case 'A', A = value;
                    case 'alpha', alpha = value;
                    case 'T', T = value;
                    otherwise
                        error('Truss:InputError', 'Unknown metadata "%s" (line %d).', parts{1}, lineNumber);
                end
        end
    end

    n = size(node,1);
    if n < 2 || isempty(element)
        error('Truss:InputError', 'At least two nodes and one element are required.');
    end
    if ~isfinite(E) || E <= 0 || ~isfinite(A) || A <= 0
        error('Truss:InputError', 'Metadata E and A must be finite and strictly positive.');
    end
    if any(element(:) > n)
        error('Truss:InputError', 'Element references a node that does not exist.');
    end
    % Duplicate members in either orientation are almost always accidental.
    if size(unique(sort(element,2), 'rows'),1) ~= size(element,1)
        error('Truss:InputError', 'Duplicate element connectivity detected.');
    end
    delta = node(element(:,2),:) - node(element(:,1),:);
    if any(sum(delta.^2, 2) <= 0)
        error('Truss:InputError', 'Zero-length element detected.');
    end

    force = zeros(2*n, 1);
    BC = NaN(2*n, 1);
    assigned = false(2*n, 1);
    for r = 1:numel(forceRows)
        record = forceRows{r}; parts = record{1}; lineNo = record{2};
        id = parseId(parts{1}, 'n', lineNo);
        checkNodeRange(id, n, lineNo);
        dof = 2*id-1:2*id;
        force(dof) = force(dof) + [parseNumber(parts{2}, lineNo); parseNumber(parts{3}, lineNo)];
    end
    for r = 1:numel(bcRows)
        record = bcRows{r}; parts = record{1}; lineNo = record{2};
        id = parseId(parts{1}, 'n', lineNo);
        checkNodeRange(id, n, lineNo);
        for k = 2:min(3,numel(parts))
            if isempty(parts{k}) || strcmpi(parts{k}, 'NaN'), continue; end
            dof = 2*id + k - 3;
            if assigned(dof)
                error('Truss:InputError', 'Repeated boundary condition at line %d.', lineNo);
            end
            BC(dof) = parseNumber(parts{k}, lineNo);
            assigned(dof) = true;
        end
    end
end

function requireFields(parts, expected, lineNo)
    if numel(parts) ~= expected
        error('Truss:InputError', 'Expected %d fields at line %d.', expected, lineNo);
    end
end

function value = parseNumber(token, lineNo)
    value = str2double(token);
    if ~isscalar(value) || ~isfinite(value)
        error('Truss:InputError', 'Invalid or nonfinite number at line %d.', lineNo);
    end
end

function value = parsePositiveInteger(token, lineNo)
    value = parseNumber(token, lineNo);
    if value < 1 || value ~= floor(value)
        error('Truss:InputError', 'Expected positive integer at line %d.', lineNo);
    end
end

function value = parseId(token, prefix, lineNo)
    matches = regexp(token, ['^' prefix '([1-9][0-9]*)$'], 'tokens', 'once');
    if isempty(matches)
        error('Truss:InputError', 'Invalid %s ID "%s" at line %d.', prefix, token, lineNo);
    end
    value = parsePositiveInteger(matches{1}, lineNo);
end

function checkNodeRange(id, nodeCount, lineNo)
    if id > nodeCount
        error('Truss:InputError', 'Unknown node n%d at line %d.', id, lineNo);
    end
end
