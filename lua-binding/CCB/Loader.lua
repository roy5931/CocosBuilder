local CCBLoader = {}

local function fillCallbacks(proxy, owner, names, nodes, events)
    if not owner then return end

    --Callbacks
    for i = 1, #names do
        local callbackName = names[i]
        local callbackNode = tolua.cast(nodes[i],"cc.Node")

        proxy:setCallback(callbackNode, function(sender, event)
            if owner and owner[callbackName] and "function" == type(owner[callbackName]) then
                owner[callbackName](owner, sender, event)
            else
                print("Warning: Cannot find lua function:" .. ":" .. callbackName .. " for selector")
            end
        end, events[i])
    end
end

local function fillMembers(owner, names, nodes)
    if not owner then return end

    --Variables    
    for i = 1, #names do
        local outletName = names[i]
        local outletNode = tolua.cast(nodes[i],"cc.Node")
        owner[outletName] = outletNode
        -- print("fillMembers:", outletName, outletNode)
    end
end

local function extend(node, name)
    local codePath = (CCBLoader.codeRootPath and CCBLoader.codeRootPath ~= "") and CCBLoader.codeRootPath .. "." .. name or name 
    local luaObj = require(codePath)
    for k,v in pairs(luaObj) do
        node[k] = v
    end
end

local function fillNode(proxy, ccbReader, owner, isRoot)
    local rootName  = ccbReader:getDocumentControllerName()
    local animationManager = ccbReader:getActionManager()
    local node = animationManager:getRootNode()
    -- print("fillNode:", rootName, node)

    --owner set in readCCBFromFile is proxy
    if nil ~= owner then
        --Callbacks
        local ownerCallbackNames = ccbReader:getOwnerCallbackNames() 
        local ownerCallbackNodes = ccbReader:getOwnerCallbackNodes()
        local ownerCallbackControlEvents = ccbReader:getOwnerCallbackControlEvents()
        fillCallbacks(proxy, owner, ownerCallbackNames, ownerCallbackNodes, ownerCallbackControlEvents)

        --Variables
        local ownerOutletNames = ccbReader:getOwnerOutletNames() 
        local ownerOutletNodes = ccbReader:getOwnerOutletNodes()
        fillMembers(owner, ownerOutletNames, ownerOutletNodes)
    end

    --document root
    if "" ~= rootName then
        extend(node, rootName)
        node.animationManager = animationManager
        
        --Callbacks
        local documentCallbackNames = animationManager:getDocumentCallbackNames()
        local documentCallbackNodes = animationManager:getDocumentCallbackNodes()
        local documentCallbackControlEvents = animationManager:getDocumentCallbackControlEvents()
        fillCallbacks(proxy, node, documentCallbackNames, documentCallbackNodes, documentCallbackControlEvents)

        --Variables
        local documentOutletNames = animationManager:getDocumentOutletNames()
        local documentOutletNodes = animationManager:getDocumentOutletNodes()
        fillMembers(node, documentOutletNames, documentOutletNodes)

        --[[
        if (typeof(controller.onDidLoadFromCCB) == "function")
            controller.onDidLoadFromCCB();
        ]]--
        --Setup timeline callbacks
        local keyframeCallbacks = animationManager:getKeyframeCallbacks()

        for i = 1 , #keyframeCallbacks do
            local callbackCombine = keyframeCallbacks[i]
            local beignIndex,endIndex = string.find(callbackCombine,":")
            local callbackType    = tonumber(string.sub(callbackCombine,1,beignIndex - 1))
            local callbackName    = string.sub(callbackCombine,endIndex + 1, -1)
            --Document callback

            if 1 == callbackType then
                local callfunc = cc.CallFunc:create(function(sender, event)
                    if node and node[callbackName] and type(node[callbackName]) == "function" then
                        node[callbackName](node, sender, event)
                    else
                        print("Warning: Cannot find lua function:" .. callbackName .. " for animation selector")
                    end
                end)
                animationManager:setCallFuncForLuaCallbackNamed(callfunc, callbackCombine);
            elseif 2 == callbackType and nil ~= owner then --Owner callback
                local callfunc = cc.CallFunc:create(owner[callbackName])--need check
                animationManager:setCallFuncForLuaCallbackNamed(callfunc, callbackCombine)
            end
        end
        --start animation
        local autoPlaySeqId = animationManager:getAutoPlaySequenceId()
        if -1 ~= autoPlaySeqId then
            animationManager:runAnimationsForSequenceIdTweenDuration(autoPlaySeqId, 0)
        end
    end

    --subReaders
    local subReaders = ccbReader:getSubReaders()
    -- print("subReaders:", subReaders and #subReaders or 0, subReaders)
    -- table.dump(subReaders)
    if subReaders then
        for i=1, #subReaders do
            local reader = subReaders[i]
            fillNode(proxy, reader, owner, false)
        end
    end

    if not isRoot and node and type(node.ctor) == "function" then
        node:ctor()
    end
end

local function doLoad(fileName, proxy, owner)
    if nil == proxy then
        return nil
    end

    local strFilePath = (CCBLoader.ccbiRootPath and CCBLoader.ccbiRootPath ~= "") and CCBLoader.ccbiRootPath .. fileName or fileName
    local ccbReader = proxy:createCCBReader()
    local node      = ccbReader:load(strFilePath)
    fillNode(proxy, ccbReader, owner, true)

    return node
end

------------------------------------------------------------
function CCBLoader:setRootPath(codeRoot, ccbiRoot)
    if ccbiRoot and string.sub(ccbiRoot, -1) ~= "/" then
        ccbiRoot = ccbiRoot .. "/"
    end
    
    self.codeRootPath = codeRoot or self.codeRootPath
    self.ccbiRootPath = ccbiRoot or self.ccbiRootPath
end

function CCBLoader:load(fileName, owner)
    local proxy = cc.CCBProxy:create()
    return doLoad(fileName, proxy, owner)
end

return CCBLoader