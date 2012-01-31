////////////////////////////////////////////////////////////////////////////////
//
//  ADOBE SYSTEMS INCORPORATED
//  Copyright 2008 Adobe Systems Incorporated
//  All Rights Reserved.
//
//  NOTICE: Adobe permits you to use, modify, and distribute this file
//  in accordance with the terms of the license agreement accompanying it.
//
////////////////////////////////////////////////////////////////////////////////

package spark.components
{

import flash.display.BlendMode;
import flash.display.Graphics;
import flash.events.Event;
import flash.events.FocusEvent;
import flash.events.KeyboardEvent;
import flash.geom.Rectangle;
import flash.system.IME;
import flash.system.IMEConversionMode;
import flash.text.TextFormat;
import flash.text.engine.ElementFormat;
import flash.text.engine.FontDescription;
import flash.text.engine.FontLookup;
import flash.text.engine.TextBlock;
import flash.text.engine.TextElement;
import flash.text.engine.TextLine;
import flash.ui.Keyboard;

import flashx.textLayout.compose.ITextLineCreator;
import flashx.textLayout.container.IInputManagerClient;
import flashx.textLayout.container.InputManager;
import flashx.textLayout.conversion.ConversionType;
import flashx.textLayout.conversion.ITextImporter;
import flashx.textLayout.conversion.TextFilter;
import flashx.textLayout.edit.EditManager;
import flashx.textLayout.edit.EditingMode;
import flashx.textLayout.edit.ISelectionManager;
import flashx.textLayout.edit.IUndoManager;
import flashx.textLayout.edit.SelectionFormat;
import flashx.textLayout.edit.SelectionManager;
import flashx.textLayout.edit.SelectionState;
import flashx.textLayout.edit.TextScrap;
import flashx.textLayout.edit.UndoManager;
import flashx.textLayout.elements.Configuration;
import flashx.textLayout.elements.FlowElement;
import flashx.textLayout.elements.ParagraphElement;
import flashx.textLayout.elements.SpanElement;
import flashx.textLayout.elements.TextFlow;
import flashx.textLayout.events.CompositionCompletionEvent;
import flashx.textLayout.events.DamageEvent;
import flashx.textLayout.events.FlowOperationEvent;
import flashx.textLayout.events.SelectionEvent;
import flashx.textLayout.formats.Category;
import flashx.textLayout.formats.FormatValue;
import flashx.textLayout.formats.ITextLayoutFormat;
import flashx.textLayout.formats.TextLayoutFormat;
import flashx.textLayout.operations.CutOperation;
import flashx.textLayout.operations.DeleteTextOperation;
import flashx.textLayout.operations.FlowOperation;
import flashx.textLayout.operations.FlowTextOperation;
import flashx.textLayout.operations.InsertTextOperation;
import flashx.textLayout.operations.PasteOperation;
import flashx.textLayout.tlf_internal;

import mx.core.EmbeddedFont;
import mx.core.EmbeddedFontRegistry;
import mx.core.IEmbeddedFontRegistry;
import mx.core.IFlexModuleFactory;
import mx.core.IFontContextComponent;
import mx.core.IIMESupport;
import mx.core.IUIComponent;
import mx.core.Singleton;
import mx.core.mx_internal;
import mx.events.FlexEvent;
import mx.managers.ISystemManager;
import mx.resources.ResourceManager;
import mx.utils.StringUtil;

import spark.core.CSSTextLayoutFormat;
import spark.core.IViewport;
import spark.core.ScrollUnit;
import spark.core.TextBaseClassWithStylesAndFocus;
import spark.events.TextOperationEvent;
import spark.utils.TextUtil;

//--------------------------------------
//  Events
//--------------------------------------

/**
 *  Dispached after the <code>selectionAnchorPosition</code> and/or
 *  <code>selectionActivePosition</code> properties have changed.
 *  due to a user interaction.
 *
 *  @eventType mx.events.FlexEvent.SELECTION_CHANGE
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
[Event(name="selectionChange", type="mx.events.FlexEvent")]

/**
 *  Dispatched before a user editing operation occurs.
 *  You can alter the operation, or cancel the event
 *  to prevent the operation from being processed.
 *
 *  @eventType mx.events.FlexEvent.CHANGING
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
[Event(name="changing", type="mx.events.TextOperationEvent")]

/**
 *  Dispatched after a user editing operation is complete.
 *
 *  @eventType mx.events.FlexEvent.CHANGE
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
[Event(name="change", type="mx.events.TextOperationEvent")]

/**
 *  Dispatched when the user pressed the Enter key.
 *
 *  @eventType mx.events.FlexEvent.ENTER
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
[Event(name="enter", type="mx.events.FlexEvent")]

//--------------------------------------
//  Styles
//--------------------------------------

include "../styles/metadata/AdvancedTextLayoutFormatStyles.as"
include "../styles/metadata/BasicTextLayoutFormatStyles.as"
include "../styles/metadata/NonInheritingTextLayoutFormatStyles.as"
include "../styles/metadata/SelectionFormatTextStyles.as"

//--------------------------------------
//  Other metadata
//--------------------------------------

[DefaultProperty("content")]

[IconFile("RichEditableText.png")]

/**
 *  Displays text. 
 *  
 *  <p>TextView has more functionality than TextBox and TextGraphic. In addition to the text rendering 
 *  capabilities of TextGraphic, TextView also supports hyperlinks, scrolling, selecting, and editing.</p>
 *  
 *  <p>The TextView class is similar to the mx.controls.TextArea control, except that it does 
 *  not have chrome.</p>
 *  
 *  <p>The TextView class does not support drawing a background, border, or scrollbars. To do that,
 *  you combine it with other components.</p>
 *  
 *  <p>Because TextView extends UIComponent, it can take focus and allows user interaction such as selection.</p>
 *  
 *  @see mx.graphics.TextBox
 *  @see mx.graphics.TextGraphic
 *
 *  @includeExample examples/TextViewExample.mxml
 *  
 *  @langversion 3.0
 *  @playerversion Flash 10
 *  @playerversion AIR 1.5
 *  @productversion Flex 4
 */
public class RichEditableText extends TextBaseClassWithStylesAndFocus
	implements IInputManagerClient, IViewport, IFontContextComponent, IIMESupport
{
    include "../core/Version.as";
        
    //--------------------------------------------------------------------------
    //
    //  Class initialization
    //
    //--------------------------------------------------------------------------
    
    /**
     *  @private
     */
    private static function initClass():void
    {
    	// Create a single Configuration used by all InputManager instances.
    	// It tells InputManager that we don't want it to handle the ENTER key,
    	// because we need the ENTER key to behave differently based on the
    	// 'multiline' property.
    	staticInputManagerConfiguration =
    		Configuration(InputManager.defaultInputManagerConfiguration).clone();
    	staticInputManagerConfiguration.manageEnterKey = false;
    	
    	staticTextLayoutFormat = new TextLayoutFormat;
    	
    	staticImportConfiguration = new Configuration();
    	
    	staticEmbeddedFont = new EmbeddedFont("", false, false);
    	
    	staticTextFormat = new TextFormat();
    }
    
    initClass();    
    
    //--------------------------------------------------------------------------
    //
    //  Class variables
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
	 *  Used for telling InputManager not to process the Enter key.
     */
    private static var staticInputManagerConfiguration:Configuration;
    
    /**
     *  @private
     *  Used for determining whitespace processing
     *  when the 'content' property is set.
     */
    private static var staticTextLayoutFormat:TextLayoutFormat;
        
    /**
     *  @private
     *  Used for determining whitespace processing
     *  when the 'content' property is set.
     */
    private static var staticImportConfiguration:Configuration;
    
    /**
     *  @private
     *  Used in getEmbeddedFontContext().
     */
    private static var staticEmbeddedFont:EmbeddedFont;
        
    /**
     *  @private
     *  Used in getEmbeddedFontContext().
     */
    private static var staticTextFormat:TextFormat;
        
    /**
     *  @private
	 *  Used for debugging.
	 *  Set this to true to get trace output
	 *  showing what InputManager APIs are being called.
     */
    mx_internal static var debug:Boolean = false;
    
    /**
     *  @private
     *  Used for debugging.
     *  Set this to an RGB uint to draw an opaque background
     *  so that you can see the bounds of the component.
     *  If it is null, the background is black pixels at 0 alpha,
     *  to be transparent but catch mouse events.
     */
    mx_internal static var backgroundColor:Object = null; // 0xDDDDDD;

    //--------------------------------------------------------------------------
    //
    //  Class properties
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  embeddedFontRegistry
    //----------------------------------

    /**
     *  @private
     *  Storage for the _embeddedFontRegistry property.
     *  Note: This gets initialized on first access,
     *  not when this class is initialized, in order to ensure
     *  that the Singleton registry has already been initialized.
     */
    private static var _embeddedFontRegistry:IEmbeddedFontRegistry;

    /**
     *  @private
     *  A reference to the embedded font registry.
     *  Single registry in the system.
     *  Used to look up the moduleFactory of a font.
     */
    private static function get embeddedFontRegistry():IEmbeddedFontRegistry
    {
        if (!_embeddedFontRegistry)
        {
            _embeddedFontRegistry = IEmbeddedFontRegistry(
                Singleton.getInstance("mx.core::IEmbeddedFontRegistry"));
        }

        return _embeddedFontRegistry;
    }

    //--------------------------------------------------------------------------
    //
    //  Class methods
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    private static function splice(str:String, start:int, end:int,
                                   strToInsert:String):String
    {
        return str.substring(0, start) +
               strToInsert +
               str.substring(end, str.length);
    }

    //--------------------------------------------------------------------------
    //
    //  Constructor
    //
    //--------------------------------------------------------------------------

    /**
     *  Constructor. 
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function RichEditableText()
    {
        super();
        
        // Create the TLF InputManager, using this component
        // as both the DisplayObjectContainer for its TextLines
        // and the implementor of its IInputManagerClient callbacks.
        // This InputManager instance persists for the lifetime
        // of the component.
        _inputManager = new InputManager(this, this, 100, 100, 
                                         staticInputManagerConfiguration);
                
        // Add event listeners on this component.
        
        addEventListener(FocusEvent.FOCUS_IN, focusInHandler);
        
        addEventListener(FocusEvent.FOCUS_OUT, focusOutHandler);
        
        addEventListener(KeyboardEvent.KEY_DOWN, keyDownHandler);
        
        addEventListener(FlexEvent.UPDATE_COMPLETE, updateCompleteHandler);
        
        // Add event listeners on its InputManager.
        
        _inputManager.addEventListener(
            CompositionCompletionEvent.COMPOSITION_COMPLETE,
            inputManager_compositionCompleteHandler);
        
        _inputManager.addEventListener(
        	DamageEvent.DAMAGE, inputManager_damageHandler);

        _inputManager.addEventListener(
        	Event.SCROLL, inputManager_scrollHandler);

        _inputManager.addEventListener(
            SelectionEvent.SELECTION_CHANGE,
            inputManager_selectionChangeHandler);

        _inputManager.addEventListener(
            FlowOperationEvent.FLOW_OPERATION_BEGIN,
            inputManager_flowOperationBeginHandler);

        _inputManager.addEventListener(
            FlowOperationEvent.FLOW_OPERATION_END,
            inputManager_flowOperationEndHandler);
    }
    
    //--------------------------------------------------------------------------
    //
    //  Variables
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     *  This object reports the TLF formats that correspond
     *  to this component's CSS styles.
     */
    private var hostFormat:ITextLayoutFormat;

    /**
     *  @private
     *  This variable is initialize to true so that hostFormat
     *  gets initialized the first time through commitProperties().
     */
    private var hostFormatChanged:Boolean = true;

    /**
     *  @private
     */
    private var stylesChanged:Boolean = false;
    
    /**
     *  @private
     */
    private var fontMetricsInvalid:Boolean = false;
    
    /**
     *  @private
     */
    private var textInvalid:Boolean = false;
        
    /**
     *  @private
     */
    private var ascent:Number;
    
    /**
     *  @private
     */
    private var descent:Number;

    /**
     *  @private
     */
    private var lastUnscaledWidth:Number = NaN;
    
    /**
     *  @private
     *  True if TextOperationEvent.CHANGING should be dispatched at
     *  operationEnd.
     */
    private var dispatchChangingEvent:Boolean = true;
    
    /**
     *  @private
     */
    mx_internal var passwordChar:String = "*";

    /**
     *  @private
     */
    mx_internal var undoManager:IUndoManager;

    /**
     *  @private
     */
    mx_internal var clearUndoOnFocusOut:Boolean = true;

    /**
     *  @private
     *  TODO! This can't be public.
     */
	public var hasScrollRect:Boolean = false;

    /**
     *  @private
     *  To preserve the selection anchor position across selection managers.
     */
    private var priorSelectionAnchorPosition:int = -1;

    /**
     *  @private
     *  To preserve the selection active position across selection managers.
     */
    private var priorSelectionActivePosition:int = -1;
    
    /**
     *  @private
     *  Holds the last recorded value of the module factory used to create the font.
     */
    mx_internal var embeddedFontContext:IFlexModuleFactory;

    /**
     *  @private
     *  Previous imeMode.
     */
    private var prevMode:String = IMEConversionMode.UNKNOWN;

    /**
     *  @private
     */    
    private var errorCaught:Boolean = false;
            
    //--------------------------------------------------------------------------
    //
    //  Overridden properties: UIComponent
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  baselinePosition
    //----------------------------------

    /**
     *  @private
     */
    override public function get baselinePosition():Number
    {
        var isEmpty:Boolean = text == "";
        
        if (isEmpty)
            text = "Wj";

        validateBaselinePosition();
        
        if (isEmpty)
            text = "";

        return getStyle("paddingTop") + ascent;
    }

    //----------------------------------
    //  enabled
    //----------------------------------

    /**
     *  @private
     */
    private var enabledChanged:Boolean = false;

    /**
     *  @private
     */
    override public function set enabled(value:Boolean):void
    {
        if (value == super.enabled)
            return;

        super.enabled = value;
        enabledChanged = true;

        invalidateProperties();
        invalidateDisplayList();
    }

    //----------------------------------
    //  explicitWidth
    //----------------------------------
    
    /**
     *  @private
     */
    override public function set explicitWidth(value:Number):void
    {
        if (value == explicitWidth)
            return;
            
        super.explicitWidth = value;
        
        // Re-measure.  The width change could impact the height.
        invalidateSize();
    }

    //----------------------------------
    //  percentWidth
    //----------------------------------
    
    /**
     *  @private
     */
    override public function set percentWidth(value:Number):void
    {
        if (value == percentWidth)
            return;
            
        super.percentWidth = value;
        
        // Re-measure.
        invalidateSize();
    }

    //--------------------------------------------------------------------------
    //
    //  Properties: IFontContextComponent
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  fontContext
    //----------------------------------
    
    /**
     *  @private
     */
    private var _fontContext:IFlexModuleFactory;

    /**
     *  @private
     */
    public function get fontContext():IFlexModuleFactory
    {
        return _fontContext;
    }

    /**
     *  @private
     */
    public function set fontContext(value:IFlexModuleFactory):void
    {
        _fontContext = value;
    }

    //--------------------------------------------------------------------------
    //
    //  Properties: IViewport
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  clipAndEnableScrolling
    //----------------------------------
        
    /**
     *  @private
     */
    private var _clipAndEnableScrolling:Boolean = true;
    
    /**
     *  @copy mx.layout.LayoutBase#clipAndEnableScrolling
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get clipAndEnableScrolling():Boolean 
    {
        return _clipAndEnableScrolling;
    }
    
    /**
     *  @private
     */
    public function set clipAndEnableScrolling(value:Boolean):void 
    {
        if (value == _clipAndEnableScrolling) 
            return;
    
        _clipAndEnableScrolling = value;
        // TBD implement this
    }
        
    //----------------------------------
    //  contentHeight
    //----------------------------------

    /**
     *  @private
     */
    private var _contentHeight:Number = 0;

    [Bindable("propertyChange")]
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get contentHeight():Number
    {
        return _contentHeight;
    }

    //----------------------------------
    //  contentWidth
    //----------------------------------

    /**
     *  @private
     */
    private var _contentWidth:Number = 0;

    [Bindable("propertyChange")]
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get contentWidth():Number
    {
        return _contentWidth;
    }

    //----------------------------------
    //  horizontalScrollPosition
    //----------------------------------

    /**
     *  @private
     */
    private var _horizontalScrollPosition:Number = 0;

    /**
     *  @private
     */
    private var horizontalScrollPositionChanged:Boolean = false;
 
    [Bindable("propertyChange")]
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get horizontalScrollPosition():Number
    {
        return _horizontalScrollPosition;
    }

    /**
     *  @private
     */
    public function set horizontalScrollPosition(value:Number):void
    {
        if (value == _horizontalScrollPosition)
            return;

        _horizontalScrollPosition = value;
        horizontalScrollPositionChanged = true;

        invalidateProperties();
    }
    
    //----------------------------------
    //  verticalScrollPosition
    //----------------------------------

    /**
     *  @private
     */
    private var _verticalScrollPosition:Number = 0;

    /**
     *  @private
     */
    private var verticalScrollPositionChanged:Boolean = false;
 
    [Bindable("propertyChange")]
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get verticalScrollPosition():Number
    {
        return _verticalScrollPosition;
    }

    /**
     *  @private
     */
    public function set verticalScrollPosition(value:Number):void
    {
        if (value == _verticalScrollPosition)
            return;

        _verticalScrollPosition = value;
        verticalScrollPositionChanged = true;

        invalidateProperties();
    }
        
    //--------------------------------------------------------------------------
    //
    //  Properties
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  autoSize
    //----------------------------------
        
    /**
     *  @private
     *  The default is true.
     *  TODO! The default should be true.
     */
    private var _autoSize:Boolean = false;

    /**
     *  @private
     */
    private var autoSizeChanged:Boolean = _autoSize;
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get autoSize():Boolean 
    {
        return _autoSize;
    }
    
    /**
     *  @private
     */
    public function set autoSize(value:Boolean):void 
    {
        if (value == _autoSize) 
            return;
    
        _autoSize = value;
        autoSizeChanged = true;
        
        invalidateProperties();
        invalidateSize();
        invalidateDisplayList();
    }
        
    //----------------------------------
    //  content
    //----------------------------------

    /**
     *  @private
     */
    private var _content:Object;

    /**
     *  @private
     */
    private var contentChanged:Boolean = false;

    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get content():Object
    {
        return _content;
    }

    /**
     *  @private
     */
    public function set content(value:Object):void
    {
        if (value == _content)
            return;

        // Setting 'content' temporarily causes 'text' to become null.
        // Later, after the 'content' has been committed into the TextFlow,
        // getting 'text' will extract the text from the TextFlow.
        _text = null;
        textChanged = false;

        _content = value;
        contentChanged = true;

        invalidateProperties();
        invalidateSize();
        invalidateDisplayList();
    }
    
    //----------------------------------
    //  displayAsPassword
    //----------------------------------

    /**
     *  @private
     */
    private var _displayAsPassword:Boolean = false;

    /**
     *  @private
     */
    private var displayAsPasswordChanged:Boolean = false;
    
    /**
     *  Documentation is not currently available.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get displayAsPassword():Boolean
    {
        return _displayAsPassword;
    }

    /**
     *  @private
     */
    public function set displayAsPassword(value:Boolean):void
    {
        if (value == _displayAsPassword)
            return;

        _displayAsPassword = value;
        displayAsPasswordChanged = true;

        invalidateProperties();
        invalidateSize();
        invalidateDisplayList();
    }

    //----------------------------------
    //  editable
    //----------------------------------

    /**
     *  @private
     */
    private var _editable:Boolean = true;

    /**
     *  @private
     */
    private var editableChanged:Boolean = false;

    /**
     *  Specifies whether the user is allowed to edit the text in this control.
     *
     *  @default true;
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get editable():Boolean
    {
        return _editable;
    }

    /**
     *  @private
     */
    public function set editable(value:Boolean):void
    {
        if (value == _editable)
            return;

        _editable = value;
        editableChanged = true;

        invalidateProperties();
        invalidateDisplayList();
    }

    //----------------------------------
    //  editingMode
    //----------------------------------
    
    /**
     *  @private
     *  The editingMode of this component's InputManager.
     *  Note that this is not a public property
     *  and does not use the invalidation mechanism.
     */
    private function get editingMode():String
    {
    	return _inputManager.editingMode;
    }
    
    /**
     *  @private
     */
    private function set editingMode(value:String):void
    {
    	if (mx_internal::debug)
     		trace("editingMode = ", value);
     	_inputManager.editingMode = value;
    }

    //----------------------------------
    //  heightInLines
    //----------------------------------

    /**
     *  @private
     */
    private var _heightInLines:Number = 10;

    /**
     *  @private
     */
    private var heightInLinesChanged:Boolean = false;
    
    /**
     *  The height of the control, in lines.
     *  
     *  <p>TextView's measure() method does not determine the measured size from 
     *  the text to be displayed, because a TextView often starts out with no 
     *  text. Instead it uses this property, and the widthInChars property 
     *  to determine its measuredWidth and measuredHeight. These are 
     *  similar to the cols and rows of an HTML TextArea.</p>
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get heightInLines():Number
    {
        return _heightInLines;
    }

    /**
     *  @private
     */
    public function set heightInLines(value:Number):void
    {
        if (value == _heightInLines)
            return;

        _heightInLines = value;
        heightInLinesChanged = true;

        invalidateSize();
        invalidateDisplayList();
    }
    
    //----------------------------------
    //  imeMode
    //----------------------------------

    /**
     *  @private
     */
    private var _imeMode:String = null;

    /**
     *  Specifies the IME (input method editor) mode.
     *  The IME enables users to enter text in Chinese, Japanese, and Korean.
     *  Flex sets the specified IME mode when the control gets the focus,
     *  and sets it back to the previous value when the control loses the focus.
     *
     *  <p>The flash.system.IMEConversionMode class defines constants for the
     *  valid values for this property.
     *  You can also specify <code>null</code> to specify no IME.</p>
     *
     *  @default null
     * 
     * @see flash.system.IMEConversionMode
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
     public function get imeMode():String
    {
        return _imeMode;
    }

    /**
     *  @private
     */
    public function set imeMode(value:String):void
    {
        _imeMode = value;
    }

    //----------------------------------
    //  inputManager
    //----------------------------------

    /**
     *  @private
     */
    private var _inputManager:InputManager; /*** public? ***/
            
    /**
     *  @private
     *  The TLF InputManager instance that displays,
     *  scrolls, and edits the text in this component.
     */
	mx_internal function get inputManager():InputManager
	{
		return _inputManager;
	}
	
    //----------------------------------
    //  maxChars
    //----------------------------------

    /**
     *  @private
     */
    private var _maxChars:int = 0;

    /**
     *  The maximum number of characters that the TextView can contain,
     *  as entered by a user.
     *  A script can insert more text than maxChars allows;
     *  the maxChars property indicates only how much text a user can enter.
     *  If the value of this property is 0,
     *  a user can enter an unlimited amount of text. 
     * 
     *  @default 0
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get maxChars():int 
    {
        return _maxChars;
    }
    
    /**
     *  @private
     */
    public function set maxChars(value:int):void
    {
        _maxChars = value;
    }

    //----------------------------------
    //  multiline
    //----------------------------------

    /**
     *  @private
     */
    private var _multiline:Boolean = true;

    /**
     *  Determines whether the user can enter multiline text.
     *  If <code>true</code>, the Enter key starts a new paragraph.
     *  If <code>false</code>, the Enter key doesn't affect the text
     *  but causes the TextView to dispatch an <code>"enter"</code> event.
     * 
     *  @default true
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get multiline():Boolean 
    {
        return _multiline;
    }
    
    /**
     *  @private
     */
    public function set multiline(value:Boolean):void
    {
        _multiline = value;
    }

    //----------------------------------
    //  restrict
    //----------------------------------

    /**
     *  @private
     */
    private var _restrict:String = null;

    /**
     *  Documentation is not currently available.
     * 
     *  @default null
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get restrict():String 
    {
        return _restrict;
    }
    
    /**
     *  @private
     */
    public function set restrict(value:String):void
    {
        _restrict = value;
    }

    //----------------------------------
    //  selectable
    //----------------------------------

    /**
     *  @private
     */
    private var _selectable:Boolean = true;

    /**
     *  @private
     */
    private var selectableChanged:Boolean = false;

    /**
     *  Specifies whether the text can be selected.
     *  Making the text selectable lets you copy text from the control.
     *
     *  @default true;
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get selectable():Boolean
    {
        return _selectable;
    }

    /**
     *  @private
     */
    public function set selectable(value:Boolean):void
    {
        if (value == _selectable)
            return;

        _selectable = value;
        selectableChanged = true;

        invalidateProperties();
        invalidateDisplayList();
    }

    //----------------------------------
    //  selectionActivePosition
    //----------------------------------

    /**
     *  @private
     */
    private var _selectionActivePosition:int = -1;

	[Bindable("selectionChange")]

    /**
     *  The active position of the selection.
     *  The "active" point is the end of the selection
     *  which is changed when the selection is extended.
     *  The active position may be either the start
     *  or the end of the selection. 
     *
     *  @default -1
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get selectionActivePosition():int
    {
        return _selectionActivePosition;
    }

    //----------------------------------
    //  selectionAnchorPosition
    //----------------------------------
    
    /**
     *  @private
     */
    private var _selectionAnchorPosition:int = -1;

	[Bindable("selectionChange")]

    /**
     *  The anchor position of the selection.
     *  The "anchor" point is the stable end of the selection
     *  when the selection is extended.
     *  The anchor position may be either the start
     *  or the end of the selection.
     *
     *  @default -1
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get selectionAnchorPosition():int
    {
        return _selectionAnchorPosition;
    }

    //----------------------------------
    //  selectionVisibility
    //----------------------------------

    /**
     *  @private
     */
    private var _selectionVisibility:String =
        TextSelectionVisibility.WHEN_FOCUSED;

    /**
     *  @private
     *  To indicate either selection visibility or selection styles have
     *  changed.
     */
    private var selectionFormatsChanged:Boolean = false;

    /**
     *  Documentation is not currently available.
     *  
     *  Possible values are <code>ALWAYS</code>, <code>WHEN_FOCUSED</code>, and <code>WHEN_ACTIVE</code>.
     *  
     *  @see mx.components.TextSelectionVisibility
     * 
     *  @default TextSelectionVisibility.WHEN_FOCUSED
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get selectionVisibility():String 
    {
        return _selectionVisibility;
    }
    
    /**
     *  @private
     */
    public function set selectionVisibility(value:String):void
    {
        if (value == _selectionVisibility)
            return;
            
        _selectionVisibility = value;
        selectionFormatsChanged = true;
        
        invalidateProperties();
        invalidateDisplayList();
    }

    //----------------------------------
    //  text
    //----------------------------------

    /**
     *  @private
     */
    private var _text:String = "";

    /**
     *  @private
     */
    private var textChanged:Boolean = false;

    /**
     *  The text String displayed by this TextView.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get text():String 
    {
        if (textInvalid && !displayAsPassword)
        {
            _text = TextUtil.extractText(textFlow);
            textInvalid = false;
        }

        return _text;
    }
    
    /**
     *  @private
     */
    public function set text(value:String):void
    {
        // Setting 'text' temporarily causes 'content' to become null.
        // Later, after the 'text' has been committed into the TextFlow,
        // getting 'content' will return the TextFlow.
        _content = null;
        contentChanged = false;
        
        _text = value;
        textChanged = true;
        
        invalidateProperties();
        invalidateSize();
        invalidateDisplayList();
    }
    
    //----------------------------------
    //  textFlow
    //----------------------------------
    
    /**
     *  Documentation is not currently available.
     */
    public function get textFlow():TextFlow
    {
    	if (mx_internal::debug)
    		trace("getTextFlow()");
    	return _inputManager.getTextFlow();
    }
    
    //----------------------------------
    //  widthInChars
    //----------------------------------

    /**
     *  @private
     *  These are measured in ems.
     */
    private var _widthInChars:Number = 15;

    /**
     *  @private
     */
    private var widthInCharsChanged:Boolean = true;
        
    /**
     *  The default width for the TextInput, measured in em units.
     *  Em is defined as simply the current point size.  The width
     *  of the "M" character is used for the calculation.
     *
     *  @default
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function get widthInChars():Number 
    {
        return _widthInChars;
    }
    
    /**
     *  @private
     */
    public function set widthInChars(value:Number):void
    {
        if (value == _widthInChars)
            return;

        _widthInChars = value;
        widthInCharsChanged = true;
        
        invalidateSize();
        invalidateDisplayList();
    }
    
    //--------------------------------------------------------------------------
    //
    //  Methods: UIComponent
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    override protected function commitProperties():void
    {
        super.commitProperties();
        
        if (hostFormatChanged)
        {
	        // If the CSS styles for this component specify an embedded font,
	        // embeddedFontContext will be set to the module factory that
	        // should create TextLines (since they must be created in the
	        // SWF where the embedded font is.)
	        // Otherwise, this will be null.
            mx_internal::embeddedFontContext = getEmbeddedFontContext();
            
            if (mx_internal::debug)
            	trace("hostFormat=");
            _inputManager.hostFormat =
            	hostFormat = new CSSTextLayoutFormat(this);
       			// Note: CSSTextLayoutFormat has special processing
        		// for the fontLookup style. If it is "auto",
        		// the fontLookup format is set to either
        		// "device" or "embedded" depending on whether
        		// embeddedFontContext is null or non-null.

            hostFormatChanged = false;
        }
        
        if (selectionFormatsChanged)
        {
        	if (mx_internal::debug)
        		trace("invalidateInteractionManager()");
        	_inputManager.invalidateInteractionManager();
        	
        	selectionFormatsChanged = false;
        }

        if (textChanged)
        {
        	if (mx_internal::debug)
        		trace("setText()");
        	_inputManager.setText(_text);
        	
        	textChanged = false;
        }
        else if (contentChanged)
        {
        	var textFlow:TextFlow = createTextFlowFromContent();
        	
        	textInvalid = true;
        	dispatchEvent(new Event("textInvalid"));
        	
        	if (mx_internal::debug)
        		trace("setTextFlow()");
        	_inputManager.setTextFlow(textFlow);
        	
        	contentChanged = false;
        }
        
        if (enabledChanged || selectableChanged || editableChanged)
        {
        	updateEditingMode();
        	
            enabledChanged = false;
            editableChanged = false;
            selectableChanged = false;        	
        }
        
        if (autoSizeChanged)
        {
            var value:String = _autoSize ? "off" : "auto";
            _inputManager.horizontalScrollPolicy = value;
            _inputManager.verticalScrollPolicy = value; 
                         
            autoSizeChanged = false;
        }
        
        if (horizontalScrollPositionChanged)
        {
            var oldHorizontalScrollPosition:Number = 
                _inputManager.horizontalScrollPosition;
            _inputManager.horizontalScrollPosition =
                _horizontalScrollPosition;            
            dispatchPropertyChangeEvent("horizontalScrollPosition",
                oldHorizontalScrollPosition, _horizontalScrollPosition);
            
            horizontalScrollPositionChanged = false;            
        }
        
        if (verticalScrollPositionChanged)
        {
            var oldVerticalScrollPosition:Number = 
                _inputManager.verticalScrollPosition;
            _inputManager.verticalScrollPosition =
                _verticalScrollPosition;
            dispatchPropertyChangeEvent("verticalScrollPosition",
                oldVerticalScrollPosition, _verticalScrollPosition);
            
            verticalScrollPositionChanged = false;            
        }
    }

    /**
     *  @private
     */
    override protected function skipMeasure():Boolean
    {
        // If autoSize, always measure.
        if (_autoSize)
            return false;
                       
        return super.skipMeasure();
    }

    /**
     *  @private
     */
    override protected function measure():void 
    {
        super.measure();
        
        // Recalculate the ascent, and descent
        // if these might have changed.
        if (fontMetricsInvalid)
        {
            calculateFontMetrics();    
            fontMetricsInvalid = false;
        }
    
        if (_autoSize)
        {
            // percentWidth is a special case for autoSize since we need
            // updateDisplay() to first tell us the unscaledWidth that has
            // been calculated from the percentWidth.
            if (isSpecialCase())
            {
                if (!isNaN(lastUnscaledWidth))
                {
                    // second time thru - max width is known
                    measureUsingWidth(lastUnscaledWidth);
                }
                else
                {
                    // first time thru - can't determine width
                    measuredWidth = 0;
                    measuredHeight = 0;
                }
            }
            else
            {
                // Normal autoSize.  If toFit will compose up to maxWidth
                // width.  If explicit, will compose entire width of text.
                measureUsingWidth(!isNaN(explicitWidth) ? explicitWidth : maxWidth);               
            }
        }
        else
        {
            measuredWidth = Math.round(calculateWidthInChars());
            measuredHeight = Math.ceil(calculateHeightInLines());            
        }    
               
        //trace("measure", measuredWidth, measuredHeight);
    }

    /**
     *  @private
     */
    override protected function updateDisplayList(unscaledWidth:Number,
                                                  unscaledHeight:Number):void 
    {
        //trace("updateDisplayList", unscaledWidth, unscaledHeight);

        super.updateDisplayList(unscaledWidth, unscaledHeight);

        if (isSpecialCase())
        {
            var firstTime:Boolean = isNaN(lastUnscaledWidth) ||
            						lastUnscaledWidth != unscaledWidth;
            lastUnscaledWidth = unscaledWidth;
            if (firstTime)
            {
                invalidateSize();
                return;
            }
        }

        // Don't trigger a damage event since we know we're recomposing.
        _inputManager.removeEventListener(
        	DamageEvent.DAMAGE, inputManager_damageHandler);
        
        // If autoSize, the text flow is already composed (although there are
        // certain styles that require a recompose since the composition width
        // and height matter).  Setting the composition size since it will 
        // trigger a damage event.
        if (!_autoSize || recomposeForStyles())
        {                     
            _inputManager.compositionWidth = unscaledWidth;
            _inputManager.compositionHeight = unscaledHeight;
        }

		if (mx_internal::debug)
			trace("updateToController()");
        if (mx_internal::embeddedFontContext)
            _inputManager.textLineCreator = ITextLineCreator(mx_internal::embeddedFontContext);
        else
            _inputManager.textLineCreator = null;
        _inputManager.updateToController();
        
        // Reinstate the damage handler.
        _inputManager.addEventListener(
        	DamageEvent.DAMAGE, inputManager_damageHandler);        
    }

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function stylesInitialized():void
    {
        super.stylesInitialized();

        fontMetricsInvalid = true;
        hostFormatChanged = true;
        stylesChanged = true;
    }

    /**
     *  @inheritDoc
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    override public function styleChanged(styleProp:String):void
    {
        super.styleChanged(styleProp);

        if (styleProp == null || styleProp == "styleName" ||
            styleProp == "fontFamily" || styleProp == "fontSize")
        {
            fontMetricsInvalid = true;
        }

        // If null or "styleName" is passed, indicating that
        // multiple styles may have changed, set a flag indicating
        // that hostContainerFormat, hostParagraphFormat,
        // and hostCharacterFormat need to be recalculated later.
        // But if a single style has changed, update the corresponding
        // property in either hostContainerFormat, hostParagraphFormat,
        // or hostCharacterFormat immediately.
        if (styleProp == null || styleProp == "styleName")
        {
            hostFormatChanged = true;
            selectionFormatsChanged = true;
        }
        else if (isSelectionFormat(styleProp))
        {
            selectionFormatsChanged = true;
        }
        else
        {
            hostFormatChanged = true;
        }

        // Need to regenerate text flow.
        invalidateProperties();

        stylesChanged = true;
    }

    //--------------------------------------------------------------------------
    //
    //  Methods: IInputManagerClient
    //
    //--------------------------------------------------------------------------

    /**
     *  Documentation is not currently available.
     */
    public function drawBackgroundAndSetScrollRect(
    					inputManager:InputManager,
    					scrollX:Number, scrollY:Number):Boolean
	{
		var width:Number = inputManager.compositionWidth;
		var height:Number = inputManager.compositionHeight;
		
		if (isNaN(width) || isNaN(height))
			return false; // just measuring!
		
		if (scrollX == 0 &&
			scrollY == 0 &&
			inputManager.contentWidth <= width &&
			inputManager.contentHeight <= height)
		{
			// skip the scrollRect
			if (hasScrollRect)
			{
				scrollRect = null;
				hasScrollRect = false;					
			}
		}
		else
		{
			scrollRect = new Rectangle(scrollX, scrollY, width, height);
			hasScrollRect = true;
		}
		
        // Client must draw a background, even it if is 100% transparent.
		var g:Graphics = graphics;
		g.clear();
        g.lineStyle();
        var bc:Object = mx_internal::backgroundColor;
        if (bc != null)
			g.beginFill(uint(bc)); 
        else
        	g.beginFill(0x000000, 0);
       	g.drawRect(scrollX, scrollY, width, height);
        g.endFill();
        
        return hasScrollRect;
	}
		
	/**
	 *  Documentation is not currently available.
	 */
	public function getUndoManager(
						inputManager:InputManager):IUndoManager
	{
		if (!mx_internal::undoManager)
		{
			mx_internal::undoManager = new UndoManager();
			mx_internal::undoManager.undoAndRedoItemLimit = int.MAX_VALUE;
		}
			
		return mx_internal::undoManager;
	}
	
	/**
	 *  Documentation is not currently available.
	 */
	public function getFocusSelectionFormat(
						inputManager:InputManager):SelectionFormat
	{
        var selectionColor:* = getStyle("selectionColor");

        // The insertion point is black, inverted, which makes it
        // the inverse color of the background, for maximum readability.         
        return new SelectionFormat(
        	selectionColor, 1.0, BlendMode.NORMAL, 
			0x000000, 1.0, BlendMode.INVERT);
	}
    
	/**
	 *  Documentation is not currently available.
	 */
	public function getNoFocusSelectionFormat(
						inputManager:InputManager):SelectionFormat
	{
        var unfocusedSelectionColor:* = getStyle("unfocusedSelectionColor");

        var unfocusedAlpha:Number =
            selectionVisibility != TextSelectionVisibility.WHEN_FOCUSED ?
            1.0 :
            0.0;

        // No insertion point when no focus.
        return new SelectionFormat(
            unfocusedSelectionColor, unfocusedAlpha, BlendMode.NORMAL,
            unfocusedSelectionColor, 0.0);
	}
    
	/**
	 *  Documentation is not currently available.
	 */
	public function getInactiveSelectionFormat(
						inputManager:InputManager):SelectionFormat
	{
        var inactiveSelectionColor:* = getStyle("inactiveSelectionColor"); 

        var inactiveAlpha:Number =
            selectionVisibility == TextSelectionVisibility.ALWAYS ?
            1.0 :
            0.0;

        // No insertion point when not active.
        return new SelectionFormat(
            inactiveSelectionColor, inactiveAlpha, BlendMode.NORMAL,
            inactiveSelectionColor, 0.0);
	}
    
    //--------------------------------------------------------------------------
    //
    //  Methods: IViewport
    //
    //--------------------------------------------------------------------------

    //----------------------------------
    //  horizontalScrollPositionDelta
    //----------------------------------

    /**
     *  @copy mx.layout.LayoutBase#getHorizontalScrollPositionDelta
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getHorizontalScrollPositionDelta(scrollUnit:uint):Number
    {
        // TBD: replace provisional implementation
        var scrollR:Rectangle = scrollRect;
        if (!scrollR)
            return 0;
            
        var maxDelta:Number = contentWidth - scrollR.width - scrollR.x;
        var minDelta:Number = -scrollR.x; 
            
        switch (scrollUnit)
        {
            case ScrollUnit.UP:
                return (scrollR.x <= 0) ? 0 : -1;
                
            case ScrollUnit.DOWN:
                return (scrollR.x >= maxDelta) ? 0 : 1;
                
            case ScrollUnit.PAGE_LEFT:
                return Math.max(minDelta, -scrollR.width);
                
            case ScrollUnit.PAGE_RIGHT:
                return Math.min(maxDelta, scrollR.width);
                
            case ScrollUnit.HOME: 
                return minDelta;
                
            case ScrollUnit.END: 
                return maxDelta;
                
            default:
                return 0;
        }       
    }
    
    //----------------------------------
    //  verticalScrollPositionDelta
    //----------------------------------

    /**
     *  @copy mx.layout.LayoutBase#getVerticalScrollPositionDelta
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getVerticalScrollPositionDelta(scrollUnit:uint):Number
    {
        // TBD: replace provisional implementation
        var scrollR:Rectangle = scrollRect;
        if (!scrollR)
            return 0;
            
        var maxDelta:Number = contentHeight - scrollR.height - scrollR.y;
        var minDelta:Number = -scrollR.y;
        
        switch (scrollUnit)
        {
            case ScrollUnit.UP:
            {
                return _inputManager.getScrollDelta(-1);
            }
                
            case ScrollUnit.DOWN:
            {
                return _inputManager.getScrollDelta(1);
            }
                
            case ScrollUnit.PAGE_UP:
            {
                return Math.max(minDelta, -scrollR.height);
            }
                
            case ScrollUnit.PAGE_DOWN:
            {
                return Math.min(maxDelta, scrollR.height);
            }
                
            case ScrollUnit.HOME:
            {
                return minDelta;
            }
                
            case ScrollUnit.END:
            {
                return maxDelta;
            }
                
            default:
            {
                return 0;
            }
        }       
    }
    
    //--------------------------------------------------------------------------
    //
    //  Methods
    //
    //--------------------------------------------------------------------------
    
	/**
	 *  @private
	 *  Uses the component's CSS styles to determine the module factory
	 *  that should creates its TextLines.
	 */
	private function getEmbeddedFontContext():IFlexModuleFactory
	{
		var moduleFactory:IFlexModuleFactory;
		
		var fontLookup:String = getStyle("fontLookup");
		if (fontLookup == "auto")
        {
			var font:String = getStyle("fontFamily");
			var bold:Boolean = getStyle("fontWeight") == "bold";
			var italic:Boolean = getStyle("fontStyle") == "italic";
			
			staticEmbeddedFont.initialize(font, bold, italic);
            
            moduleFactory = embeddedFontRegistry.getAssociatedModuleFactory(
            	staticEmbeddedFont, fontContext);

            // If we found the font, then it is embedded. 
            // But some fonts are not listed in info()
            // and are therefore not in the above registry.
            // So we call isFontFaceEmbedded() which gets the list
            // of embedded fonts from the player.
            if (!moduleFactory) 
            {
                var sm:ISystemManager;
                if (fontContext != null && fontContext is ISystemManager)
                	sm = ISystemManager(fontContext);
                else if (parent is IUIComponent)
                	sm = IUIComponent(parent).systemManager;

                staticTextFormat.font = font;
                staticTextFormat.bold = bold;
                staticTextFormat.italic = italic;
                
                if (sm != null && sm.isFontFaceEmbedded(staticTextFormat))
                    moduleFactory = sm;
            }
        }
        else
        {
            moduleFactory = fontLookup == FontLookup.EMBEDDED_CFF ?
                			fontContext :
            				null;
        }
        
        return moduleFactory;
	}

    /**
     *  @private
     */
    private function getSelectionManager():SelectionManager
    {
    	return SelectionManager(_inputManager.getInteractionManager());
    }

    /**
     *  @private
     */
    private function getEditManager():EditManager
    {
    	return EditManager(_inputManager.getInteractionManager());
    }

    /**
     *  @private
     *  The cases that require a second pass through the LayoutManager.
     */
    private function isSpecialCase():Boolean
    {
        return _autoSize && !isNaN(percentWidth);
    }

    /**
     *  @private
     *  If the text is composed during measure(), there are certain styles 
     *  that require it to be recomposed again for display.  For example,
     *  if textAlign = justify the text must be composed with unscaledWidth
     *  rather than maxWidth so that the text is distributed correctly across
     *  the width.
     */
    protected function recomposeForStyles():Boolean
    {
        var direction:String = getStyle("direction");
        var textAlign:String = getStyle("textAlign");

        var leftAligned:Boolean =
            textAlign == "left" ||
            textAlign == "start" && direction == "ltr" ||
            textAlign == "end" && direction == "rtl";
    
        if (!leftAligned)
            return true;   

        var verticalAlign:String = getStyle("verticalAlign");
        var topAligned:Boolean = (verticalAlign == "top");

        return !topAligned;
    }

    /**
     *  @private
     */
    private function measureUsingWidth(maxComposeWidth:Number):void
    {
        // Never compose over the max width because the width will always
        // be adjusted down to this and it's easy to get into an infinite
        // measure/update display loop.
        var composeWidth:Number; 
        if (hostFormat.lineBreak == "toFit")
        {
            // Need to set a width to cause a wrap if text rather than 
            // formatted content.
            composeWidth = maxComposeWidth;
            explicitMinWidth = NaN;
        }
        else
        {             
            // Let the text determine the width.  Ignore explicit widths.
            composeWidth = NaN;
            explicitMinWidth = explicitMaxWidth = NaN;                
        }
        
        // Ignore all explicit heights.
        explicitMinHeight = explicitMaxHeight = NaN;
                                  
        // The bottom border can grow to allow all the text to fit.
        // If dimension is NaN, composer will measure text in that 
        // direction. 
        _inputManager.compositionWidth = composeWidth;
        _inputManager.compositionHeight = NaN;

        // Compose only.  The display is not updated.
        /**************
        flowComposer.compose();
        */
        _inputManager.updateToController();

        // If it's an empty text flow, there is one line with one
        // character so the height is good for the line.
        measuredHeight = Math.ceil(_inputManager.contentHeight);

        if (_inputManager.getText().length > 1) 
        {
            // Non-empty text flow.
            measuredWidth = Math.ceil(_inputManager.contentWidth);
        }
        else
        {
            // Empty text flow.  One Em wide with padding.
            measuredWidth = Math.ceil(getStyle("fontSize") +
                                      _inputManager.contentWidth);
       }
                
        // Lock in the compose area so all text is visible.
        measuredMinWidth = measuredWidth;                     
        measuredMinHeight = measuredHeight;           
    }

    /**
     *  @private
     *  This method is called when anything affecting the
     *  default font, size, weight, etc. changes.
     *  It calculates the 'ascent', 'descent', and
     *  instance variables, which are used in measure().
     */
    private function calculateFontMetrics():void
    {
        // If the CSS styles for this component specify an embedded font,
        // embeddedFontContext will be set to the module factory that
        // should create TextLines (since they must be created in the
        // SWF where the embedded font is.)
        // Otherwise, this will be null.
        mx_internal::embeddedFontContext = getEmbeddedFontContext();
        
        var fontDescription:FontDescription = new FontDescription();
        
        var s:String;

        s = getStyle("cffHinting");
        if (s != null)
        	fontDescription.cffHinting = s;
        
        s = getStyle("fontFamily");
        if (s != null)
        	fontDescription.fontName = s;
        
        s = getStyle("fontLookup");
        if (s != null)
        {
        	// FTE understands only "device" and "embeddedCFF"
        	// for fontLookup. But Flex allows this style to be
        	// set to "auto", in which case we automatically
        	// determine it based on whether the CSS styles
        	// specify an embedded font.
        	if (s == "auto")
        	{
        		s = mx_internal::embeddedFontContext ?
        			FontLookup.EMBEDDED_CFF :
                	FontLookup.DEVICE;
        	}
        }
         
        s = getStyle("fontStyle");
        if (s != null)
        	fontDescription.fontPosture = s;
        
        s = getStyle("fontWeight");
        if (s != null)
        	fontDescription.fontWeight = s;
        
        var elementFormat:ElementFormat = new ElementFormat();
        elementFormat.fontDescription = fontDescription;
        elementFormat.fontSize = getStyle("fontSize");
        
        var textElement:TextElement = new TextElement();
        textElement.elementFormat = elementFormat;
        textElement.text = "M";
        
        var textBlock:TextBlock = new TextBlock();
        textBlock.content = textElement;
        
        var textLine:TextLine = textBlock.createTextLine(null, 1000);
        
        ascent = textLine.ascent;
        descent = textLine.descent;
    }
    
    /**
     *  @private
     */
    private function calculateWidthInChars():Number
    {
    	var em:Number = getStyle("fontSize");
    	
    	return getStyle("paddingLeft") +
    		  widthInChars * em +
    		  getStyle("paddingRight");
    }
    
    /**
     *  @private
     *  Calculates the height needed for heightInLines lines using the default
     *  font.
     */
    private function calculateHeightInLines():Number
    {
        var height:Number = getStyle("paddingTop") + getStyle("paddingBottom");
            
        if (heightInLines == 0)
            return height;
                        
        // Position of the baseline of first line in the container.
        value = getStyle("firstBaselineOffset");
        if (value == lineHeight)
            height += lineHeight;
        else if (value is Number)
            height += Number(value);
        else
            height += ascent;

        // Distance from baseline to baseline.  Can be +/- number or 
        // or +/- percent (in form "120%") or "undefined".  
        if (heightInLines > 1)
        {
            var value:Object = getStyle("lineHeight");     
            var lineHeight:Number =
            	TextUtil.getNumberOrPercentOf(value, getStyle("fontSize"));
                
            // Default is 120%
            if (isNaN(lineHeight))
                lineHeight = getStyle("fontSize") * 1.2;
            
            height += (heightInLines - 1) * lineHeight;
        }            
        
        // Add in descent of last line.
        height += descent;              
        
        return height;
    }
        
    /**
     *  @private
     */
    private function createEmptyTextFlow():TextFlow
    {
        var textFlow:TextFlow = new TextFlow();
        var p:ParagraphElement = new ParagraphElement();
        var span:SpanElement = new SpanElement();
        textFlow.replaceChildren(0, 0, p);
        p.replaceChildren(0, 0, span);
        return textFlow;
    }
    
    /**
     *  @private
     */
    private function createTextFlowFromMarkup(markup:Object):TextFlow
    {
        // The whiteSpaceCollapse format determines how whitespace
        // is processed when markup is imported.
        staticTextLayoutFormat.lineBreak = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingLeft = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingRight = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingTop = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingBottom = FormatValue.INHERIT;
        staticTextLayoutFormat.verticalAlign = FormatValue.INHERIT;
        staticTextLayoutFormat.whiteSpaceCollapse =
            getStyle("whiteSpaceCollapse");
        staticImportConfiguration.textFlowInitialFormat =
            staticTextLayoutFormat;

        if (markup is XML || markup is String)
        {
            // We need to wrap the markup in a <TextFlow> tag
            // unless it already has one.
            // Note that we avoid trying to convert it to XML
            // (in order to test whether the outer tag is <TextFlow>)
            // unless it contains the substring "TextFlow".
            // And if we have to do the conversion, then
            // we use the markup in XML form rather than
            // having TLF reconvert it to XML.
            var wrap:Boolean = true;
            if (markup is XML || markup.indexOf("TextFlow") != -1)
            {
                try
                {
                    var xmlMarkup:XML = XML(markup);
                    if (xmlMarkup.localName() == "TextFlow")
                    {
                        wrap = false;
                        markup = xmlMarkup;
                    }
                }
                catch(e:Error)
                {
                }
            }

            if (wrap)
            {
                if (markup is String)
                {
                    markup = 
                        '<TextFlow xmlns="http://ns.adobe.com/textLayout/2008">' +
                        markup +
                        '</TextFlow>';
                }
                else
                {
                    // It is XML.  Create a root element and add the markup
                    // as it's child.
                    var ns:Namespace = 
                        new Namespace("http://ns.adobe.com/textLayout/2008");
                                                 
                    xmlMarkup = <TextFlow />;
                    xmlMarkup.setNamespace(ns);            
                    xmlMarkup.setChildren(markup);  
                                        
                    // The namespace of the root node is not inherited by
                    // the children so it needs to be explicitly set on
                    // every element, at every level.  If this is not done
                    // the import will fail with an "Unexpected namespace"
                    // error.
                    for each (var element:XML in xmlMarkup..*::*)
                       element.setNamespace(ns);

                    markup = xmlMarkup;
                }
            }
        }
        
        return importToFlow(markup, TextFilter.TEXT_LAYOUT_FORMAT,
                            staticImportConfiguration);
    }
    
    /**
     *  @private
     */
    private function createTextFlowFromChildren(children:Array):TextFlow
    {
        var textFlow:TextFlow = new TextFlow();

        // The whiteSpaceCollapse format determines how whitespace
        // is processed when the children are set.
        staticTextLayoutFormat.lineBreak = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingLeft = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingRight = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingTop = FormatValue.INHERIT;
        staticTextLayoutFormat.paddingBottom = FormatValue.INHERIT;
        staticTextLayoutFormat.verticalAlign = FormatValue.INHERIT;
        staticTextLayoutFormat.whiteSpaceCollapse =
            getStyle("whiteSpaceCollapse");
        textFlow.hostFormat = staticTextLayoutFormat;

        textFlow.mxmlChildren = children;

        return textFlow;
    }

    /**
     *  @private
     */
    private function createTextFlowFromContent():TextFlow
    {
    	var textFlow:TextFlow;
    	
        if (_content is TextFlow)
        {
            textFlow = TextFlow(_content);
        }
        else if (_content is Array)
        {
            textFlow = createTextFlowFromChildren(_content as Array);
        }
        else if (_content is FlowElement)
        {
            textFlow = createTextFlowFromChildren([ _content ]);
        }
        else if (_content is String || _content is XML)
        {
            textFlow = createTextFlowFromMarkup(_content);
        }
        else if (_content == null)
        {
            textFlow = createEmptyTextFlow();
        }
        else
        {
            textFlow = createTextFlowFromMarkup(_content.toString());
        }
        
        return textFlow;
    }
    
    /**
     *  @private
     *  This will throw on import error.
     */
    private function importToFlow(source:Object, format:String, 
                                  config:Configuration = null):TextFlow
    {
        var importer:ITextImporter = TextFilter.getImporter(format);
        
        // Throw import errors rather than return a null textFlow.
        // Alternatively, the error strings are in the Vector, importer.errors.
        importer.throwOnError = true;
        
        return importer.importToFlow(source);        
    }

    /**
     *  @private
     *  Is this a style associated with the SelectionFormat?
     */
    private function isSelectionFormat(styleProp:String):Boolean
    {        
        return styleProp &&
               (styleProp == "selectionColor" || 
                styleProp == "unfocusedSelectionColor" ||
                styleProp == "inactiveSelectionColor");
    }
       
    /**
     *  @private
     */
    private function updateEditingMode():void
    {
    	var newEditingMode:String = EditingMode.READ_ONLY;
    	
    	if (enabled)
    	{
    		if (_editable)
    			newEditingMode = EditingMode.READ_WRITE;
    		else if (_selectable)
    			newEditingMode = EditingMode.READ_SELECT;
    	}
    	
  		editingMode = newEditingMode;
    }
        
    /**
     *  Sets the selection range and.  If the text is not editable or selectable
     *  this will also implicitly make the text selectable.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setSelection(anchorPosition:int = 0,
                                 activePosition:int = int.MAX_VALUE):void
    {
        if (editingMode == EditingMode.READ_ONLY)
        {
            editingMode = EditingMode.READ_SELECT;
            _selectable = true;
        }

		var selectionManager:SelectionManager = getSelectionManager();
        
        selectionManager.setSelection(anchorPosition, activePosition);        
                
        // Update the display with the new selection.
        selectionManager.refreshSelection();
      }
    
    /**
     *  Inserts the specified text as if you had typed it.
     *  If a range was selected, the new text replaces the selected text;
     *  if there was an insertion point, the new text is inserted there,
     *  otherwise the text is appended to the text that is there.
     *  An insertion point is then set after the new text.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function insertText(text:String):void
    {        
        // Make sure all properties are committed before doing the insert.
        validateNow();

        // Always use the EditManager regardless of the values of
        // selectable, editable and enabled.
        var priorEditingMode:String = editingMode;
        editingMode = EditingMode.READ_WRITE;
        var editManager:EditManager = getEditManager();
        
        // If no selection, then it's an append.
         if (!editManager.hasSelection())
            editManager.setSelection(int.MAX_VALUE, int.MAX_VALUE);       
        editManager.insertText(text);

        // Update TLF display.  This initiates the InsertTextOperation.
        _inputManager.updateToController();        

        // Restore the prior editing mode.
        editingMode = priorEditingMode;
    }
    
    /**
     *  Appends the specified text to the end of the TextView,
     *  as if you had clicked at the end and typed it.
     *  When TextView supports vertical scrolling,
     *  it will scroll to ensure that the last line
     *  of the inserted text is visible.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function appendText(text:String):void
    {
        // Make sure all properties are committed before doing the append.
        validateNow();

        // Always use the EditManager regardless of the values of
        // selectable, editable and enabled.
        var priorEditingMode:String = editingMode;
        editingMode = EditingMode.READ_WRITE;
        var editManager:EditManager = getEditManager();
        
        // An append is an insert with the selection set to the end.
        editManager.setSelection(int.MAX_VALUE, int.MAX_VALUE);
        editManager.insertText(text);

        // Update TLF display.  This initiates the InsertTextOperation.
        _inputManager.updateToController();        

        // Restore the prior editing mode.
        editingMode = priorEditingMode;
    }

    /**
     *  Returns a String containing markup describing
     *  this TextView's TextFlow.
     *  This markup String has the appropriate format
     *  for setting the <code>content</code> property.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function export():XML
    {
        return XML(TextFilter.export(textFlow, TextFilter.TEXT_LAYOUT_FORMAT,
                                     ConversionType.XML_TYPE));
    }

    /**
     *  Returns an Object containing name/value pairs of text attributes
     *  for the specified range.
     *  If an attribute is not consistently set across the entire range,
     *  its value will be null.
     *  You can specify an Array containing names of the attributes
     *  that you want returned; if you don't, all attributes will be returned.
     *  If you don't specify a range, the selected range is used.
     *  For example, calling
     *  <code>getSelectionFormat()</code>
     *  might return <code>({ fontSize: 12, color: null })</code>
     *  if the selection is uniformly 12-point but has multiple colors.
     *  The supported attributes are those in the
     *  ICharacterAttributes and IParagraphAttributes interfaces.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function getSelectionFormat(names:Array = null):Object
    {
        var format:Object = {};
        
        // Switch to the EditManager.
        var priorEditingMode:String = editingMode;
        editingMode = EditingMode.READ_WRITE;
        var selectionManager:SelectionManager = getSelectionManager();
                
        // This internal TLF object maps the names of format properties
        // to Property instances.
        // Each Property instance has a category property which tells
        // whether it is container-, paragraph-, or character-level.
        var description:Object = TextLayoutFormat.tlf_internal::description;
            
        var p:String;
        var category:String;
        
        // Based on which formats have been requested, determine which
        // of the getCommonXXXFormat() methods we need to call.

        var needContainerFormat:Boolean = false;
        var needParagraphFormat:Boolean = false;
        var needCharacterFormat:Boolean = false;

        if (!names)
        {
            names = [];
            for (p in description)
                names.push(p);
            
            needContainerFormat = true;
            needParagraphFormat = true;
            needCharacterFormat = true;
        }
        else
        {
            for each (p in names)
            {
                category = description[p].category;

                if (category == Category.CONTAINER)
                    needContainerFormat = true;
                else if (category == Category.PARAGRAPH)
                    needParagraphFormat = true;
                else if (category == Category.CHARACTER)
                    needCharacterFormat = true;
            }
        }

        // Get the common formats.
        
        var containerFormat:ITextLayoutFormat;
        var paragraphFormat:ITextLayoutFormat;
        var characterFormat:ITextLayoutFormat;
        
        if (needContainerFormat)
            containerFormat = selectionManager.getCommonContainerFormat();
        
        if (needParagraphFormat)
            paragraphFormat = selectionManager.getCommonParagraphFormat();

        if (needCharacterFormat)
            characterFormat = selectionManager.getCommonCharacterFormat();

        // Extract the requested formats to return.
        for each (p in names)
        {
            category = description[p].category;
            
            if (category == Category.CONTAINER && containerFormat)
                format[p] = containerFormat[p];
            else if (category == Category.PARAGRAPH && paragraphFormat)
                format[p] = paragraphFormat[p];
            else if (category == Category.CHARACTER && characterFormat)
                format[p] = characterFormat[p];
        }
        
        // Restore the prior editing mode.
        editingMode = priorEditingMode;
                
        return format;
    }

    /**
     *  Applies a set of name/value pairs of text attributes
     *  to the specified range.
     *  A value of null does not get applied.
     *  If you don't specify a range, the selected range is used.
     *  For example, calling
     *  <code>setSelectionFormat({ fontSize: 12, color: 0xFF0000 })</code>
     *  will set the fontSize and color of the selection.
     *  The supported attributes are those in the
     *  ICharacterFormat and IParagraphFormat interfaces.
     *  
     *  @langversion 3.0
     *  @playerversion Flash 10
     *  @playerversion AIR 1.5
     *  @productversion Flex 4
     */
    public function setSelectionFormat(attributes:Object):void
    {
        // Switch to the EditManager.
        var priorEditingMode:String = editingMode;
        editingMode = EditingMode.READ_WRITE;
        var editManager:EditManager = getEditManager();
        
        // Assign each specified attribute to one of three format objects,
        // depending on whether it is container-, paragraph-,
        // or character-level. Note that these can remain null.
        var containerFormat:TextLayoutFormat;
        var paragraphFormat:TextLayoutFormat;
        var characterFormat:TextLayoutFormat;

        // This internal TLF object maps the names of format properties
        // to Property instances.
        // Each Property instance has a category property which tells
        // whether it is container-, paragraph-, or character-level.
        var description:Object = TextLayoutFormat.tlf_internal::description;
        
        for (var p:String in attributes)
        {
            var category:String = description[p].category;
            
            if (category == Category.CONTAINER)
            {
                if (!containerFormat)
                   containerFormat =  new TextLayoutFormat();
                containerFormat[p] = attributes[p];
            }
            else if (category == Category.PARAGRAPH)
            {
                if (!paragraphFormat)
                   paragraphFormat =  new TextLayoutFormat();
                paragraphFormat[p] = attributes[p];
            }
            else if (category == Category.CHARACTER)
            {
                if (!characterFormat)
                   characterFormat =  new TextLayoutFormat();
                characterFormat[p] = attributes[p];
            }
        }
        
        // Apply the three format objects to the current selection.
        editManager.applyFormat(
        	characterFormat, paragraphFormat, containerFormat);
        
        // Restore the prior editing mode.
        editingMode = priorEditingMode;
    }

	/**
	 *  @private
	 */
    private function handlePasteOperation(op:PasteOperation):void
    {
        if (!restrict && !maxChars && !displayAsPassword)
            return;
            
        var textScrap:TextScrap = op.scrapToPaste();
        var pastedText:String = TextUtil.extractText(textScrap.textFlow);

        // We know it's an EditManager or we wouldn't have gotten here.
        var editManager:EditManager = getEditManager();

        // Generate a CHANGING event for the PasteOperation but not for the
        // DeleteTextOperation or the InsertTextOperation which are also part
        // of the paste.
        dispatchChangingEvent = false;
                        
        var selectionState:SelectionState = new SelectionState(
        	textFlow, op.absoluteStart, op.absoluteStart + pastedText.length);             
        editManager.deleteText(selectionState);

        // Insert the same text, the same place where the paste was done.
        // This will go thru the InsertPasteOperation and do the right
        // things with restrict, maxChars and displayAsPassword.
        selectionState = new SelectionState(
        	textFlow, op.absoluteStart, op.absoluteStart);
        editManager.insertText(pastedText, selectionState);        

        dispatchChangingEvent = true;
    }

    /**
     *  @private
     */
    /*
    private function isOverset(controller:IContainerController):Boolean
    {
        // In some circumsances, the last controller gets all of the 
        // content. In this case, test contentHeight vs. compositionHeight. 
        // In other cases (the proper case) use textLengths to check.
        return controller.contentHeight > controller.compositionHeight || 
               (controller.absoluteStart + controller.textLength < 
               controller.textFlow.textLength);
    }
    */
    
    //--------------------------------------------------------------------------
    //
    //  Overridden event handlers: UIComponent
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    protected function focusInHandler(event:FocusEvent):void
    {        
        if (focusManager && multiline)
            focusManager.defaultButtonEnabled = false;

        if (_imeMode != null && _editable)
        {
            IME.enabled = true;
            prevMode = IME.conversionMode;
            // When IME.conversionMode is unknown it cannot be
            // set to anything other than unknown(English)      
            try
            {
                if (!errorCaught &&
                    IME.conversionMode != IMEConversionMode.UNKNOWN)
                {
                    IME.conversionMode = _imeMode;
                }
                errorCaught = false;
            }
            catch(e:Error)
            {
                // Once an error is thrown, focusIn is called 
                // again after the Alert is closed, throw error 
                // only the first time.
                errorCaught = true;
                var message:String = ResourceManager.getInstance().getString(
                    "controls", "unsupportedMode", [ _imeMode ]);          
                throw new Error(message);
            }
        }            
    }

    /**
     *  @private
     */
    protected function focusOutHandler(event:FocusEvent):void
    {
        // By default, we clear the undo history when a TextView loses focus.
        if (mx_internal::clearUndoOnFocusOut)
            mx_internal::undoManager.clear();
                    
        if (focusManager)
            focusManager.defaultButtonEnabled = true;

        if (_imeMode != null && _editable)
        {
            // When IME.conversionMode is unknown it cannot be
            // set to anything other than unknown(English)
            // and when known it cannot be set to unknown           
            if (IME.conversionMode != IMEConversionMode.UNKNOWN 
                && prevMode != IMEConversionMode.UNKNOWN)
                IME.conversionMode = prevMode;
            IME.enabled = false;
        }
    }

    /**
     *  @private
     */ 
    protected function keyDownHandler(event:KeyboardEvent):void
    {
        if (editingMode != EditingMode.READ_WRITE)
        	return;
        
        if (event.keyCode == Keyboard.ENTER)
        {
            if (multiline)
        		getEditManager().splitParagraph();
            else
                dispatchEvent(new FlexEvent(FlexEvent.ENTER));
         }
    }
    
    //--------------------------------------------------------------------------
    //
    //  Event handlers
    //
    //--------------------------------------------------------------------------

    /**
     *  @private
     */
    private function updateCompleteHandler(event:FlexEvent):void
    {
        lastUnscaledWidth = NaN;
    }

    /**
     *  @private
     *  Called when the InputManager dispatches a 'compositionComplete' event
     *  when it has recomposed the text into TextLines.
     */
    private function inputManager_compositionCompleteHandler(
                                    event:CompositionCompletionEvent):void
    {
        //trace("compositionComplete");
        
        var oldContentWidth:Number = _contentWidth;
        var newContentWidth:Number = _inputManager.contentWidth;
        
        // Error correction for rounding errors.  It shouldn't be so but
        // the contentWidth can be slightly larger than the requested
        // compositionWidth.
        if (newContentWidth > _inputManager.compositionWidth &&
            Math.round(newContentWidth) == _inputManager.compositionWidth)
        { 
            newContentWidth = _inputManager.compositionWidth;
        }
            
        if (newContentWidth != oldContentWidth)
        {
            _contentWidth = newContentWidth;
            
            //trace("contentWidth", oldContentWidth, newContentWidth);

            dispatchPropertyChangeEvent(
                "contentWidth", oldContentWidth, newContentWidth);
        }
        
        var oldContentHeight:Number = _contentHeight;
        var newContentHeight:Number = _inputManager.contentHeight;

        // Error correction for rounding errors.  It shouldn't be so but
        // the contentHeight can be slightly larger than the requested
        // compositionHeight.  
        if (newContentHeight > _inputManager.compositionHeight &&
            Math.round(newContentHeight) == _inputManager.compositionHeight)
        { 
            newContentHeight = _inputManager.compositionHeight;
        }
            
        if (newContentHeight != oldContentHeight)
        {
            _contentHeight = newContentHeight;
            
            //trace("contentHeight", oldContentHeight, newContentHeight);
            
            dispatchPropertyChangeEvent(
                "contentHeight", oldContentHeight, newContentHeight);
        } 
        
        // If autoSize and there is overset text, remeasure.  contentHeight
        // will not be the total height of the text unless composition is done 
        // and scrolling is *on*.
        /********************************************************
        if (_autoSize && isOverset(containerController))
            invalidateSize();
        */
    }
    
    /**
     *  @private
     *  Called when the InputManager dispatches a 'damage' event.  The TextFlow
     *  could have been modified interactively or programatically.
     */
    private function inputManager_damageHandler(event:DamageEvent):void
    {
        //trace("damageHandler", event.damageStart, event.damageLength);
        
        // The text flow changed.  It could have been either/or content or
        // styles within the flow.
        textInvalid = true;
        dispatchEvent(new Event("textInvalid"));
                    
        // If autoSize and text changed, need to remeasure.
        if (_autoSize)
            invalidateSize();
        
        invalidateDisplayList();
    }

    /**
     *  @private
     *  Called when the InputManager dispatches a 'scroll' event
     *  as it autoscrolls.
     */
    private function inputManager_scrollHandler(event:Event):void
    {
        var oldHorizontalScrollPosition:Number = _horizontalScrollPosition;
        var newHorizontalScrollPosition:Number =
            _inputManager.horizontalScrollPosition;
        if (newHorizontalScrollPosition != oldHorizontalScrollPosition)
        {
            _horizontalScrollPosition = newHorizontalScrollPosition;
            
            dispatchPropertyChangeEvent("horizontalScrollPosition",
                oldHorizontalScrollPosition, newHorizontalScrollPosition);
        }
        
        var oldVerticalScrollPosition:Number = _verticalScrollPosition;
        var newVerticalScrollPosition:Number =
            _inputManager.verticalScrollPosition;
        if (newVerticalScrollPosition != oldVerticalScrollPosition)
        {
            _verticalScrollPosition = newVerticalScrollPosition;
            
            dispatchPropertyChangeEvent("verticalScrollPosition",
                oldVerticalScrollPosition, newVerticalScrollPosition);
        }
    }

    /**
     *  @private
     *  Called when the InputManager dispatches a 'selectionChange' event.
     */
    private function inputManager_selectionChangeHandler(
                        event:SelectionEvent):void
    {
        var selectionManager:SelectionManager = getSelectionManager();

        _selectionAnchorPosition = selectionManager.anchorPosition;
        _selectionActivePosition = selectionManager.activePosition;
        
        //trace("selectionChangeHandler", _selectionAnchorPosition, _selectionActivePosition);
            
        dispatchEvent(new FlexEvent(FlexEvent.SELECTION_CHANGE));
    }

    /**
     *  @private
     *  Called when the InputManager dispatches an 'operationBegin' event
     *  before an editing operation.
     */     
    private function inputManager_flowOperationBeginHandler(
                        event:FlowOperationEvent):void
    {
        //trace("operationBegin");
        
        var op:FlowOperation = event.operation;

        if (op is InsertTextOperation)
        {
            var insertTextOperation:InsertTextOperation =
                InsertTextOperation(op);

            var textToInsert:String = insertTextOperation.text;

            // Note: Must process restrict first, then maxChars,
            // then displayAsPassword last.
            
            if (_restrict != null)
            {
                textToInsert = StringUtil.restrict(textToInsert, restrict);
                if (textToInsert.length == 0)
                {
                    event.preventDefault();
                    return;
                }
            }

            if (maxChars != 0)
            {
                var length1:int = text.length;
                var length2:int = textToInsert.length;
                if (length1 + length2 > maxChars)
                    textToInsert = textToInsert.substr(0, maxChars - length1);
            }

            if (_displayAsPassword)
            {
                _text = splice(_text, insertTextOperation.absoluteStart,
                               insertTextOperation.absoluteEnd, textToInsert);
                textToInsert = StringUtil.repeat(mx_internal::passwordChar,
                                                 textToInsert.length);
            }

            insertTextOperation.text = textToInsert;
        }
        else if (op is PasteOperation)
        {
            // Paste is implemented in operationEnd.  The basic idea is to allow 
            // the paste to go through unchanged, but group it together with a 
            // second operation that modifies text as part of the same 
            // transaction. This is vastly simpler for TLF to manage. 
        }
        else if (op is DeleteTextOperation || op is CutOperation)
        {
            var flowTextOperation:FlowTextOperation =
                FlowTextOperation(op);

            // Eat 0-length selection.  This can happen when insertion point is 
            // at start of container and a backspace generates a 
            // DeleteTextOperation.  
            if (flowTextOperation.absoluteStart == 0 && flowTextOperation.absoluteEnd == 0)
            {
                event.preventDefault();
                return;
            }           
            
            if (_displayAsPassword)
            {
                _text = splice(_text, flowTextOperation.absoluteStart,
                               flowTextOperation.absoluteEnd, "");
            }
        }
 
        // Dispatch a 'changing' event from the TextView
        // as notification that an editing operation is about to occur.
        if (dispatchChangingEvent)
        {
            var newEvent:TextOperationEvent =
                new TextOperationEvent(TextOperationEvent.CHANGING);
            newEvent.operation = op;
            dispatchEvent(newEvent);
            
            // If the event dispatched from this TextView is canceled,
            // cancel the one from the EditManager, which will prevent
            // the editing operation from being processed.
            if (newEvent.isDefaultPrevented())
                event.preventDefault();
        }
    }
    
    /**
     *  @private
     *  Called when the InputManager dispatches an 'operationEnd' event
     *  after an editing operation.
     */
    private function inputManager_flowOperationEndHandler(
                        event:FlowOperationEvent):void
    {
        //trace("operationEnd");
        
        // Paste is a special case.  Any mods have to be made to the text
        // which includes what was pasted.
        if (event.operation is PasteOperation)
            handlePasteOperation(PasteOperation(event.operation));

        // Since the text may have changed, set a flag which will
        // cause the 'text' getter to call extractText() to extract
        // the text by walking the TextFlow.
        textInvalid = true;
        dispatchEvent(new Event("textInvalid"));

        // Dispatch a 'change' event from the TextView
        // as notification that an editing operation has occurred.
        var newEvent:TextOperationEvent =
            new TextOperationEvent(TextOperationEvent.CHANGE);
        newEvent.operation = event.operation;
        dispatchEvent(newEvent);
    }
}

}
