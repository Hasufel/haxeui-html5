package haxe.ui.core;

import haxe.ui.components.VProgress;
import haxe.ui.core.Component;
import haxe.ui.core.ImageDisplay;
import haxe.ui.core.MouseEvent;
import haxe.ui.core.TextDisplay;
import haxe.ui.core.TextInput;
import haxe.ui.core.UIEvent;
import haxe.ui.html5.EventMapper;
import haxe.ui.html5.HtmlUtils;
import haxe.ui.html5.StyleHelper;
import haxe.ui.html5.UserAgent;
import haxe.ui.html5.native.NativeElement;
import haxe.ui.styles.Style;
import haxe.ui.util.GenericConfig;
import haxe.ui.util.Rectangle;
import haxe.ui.util.filters.Blur;
import haxe.ui.util.filters.DropShadow;
import haxe.ui.util.filters.FilterParser;
import js.Browser;
import js.html.CSSStyleDeclaration;
import js.html.Element;
import js.html.MutationObserver;
import js.html.MutationRecord;
import js.html.WheelEvent;

class ComponentBase {
	public var element:Element;
	private var _eventMap:Map<String, UIEvent->Void>;

	private var _nativeElement:NativeElement;
	
    private var _mutationObserver:MutationObserver;
    
	@:access(haxe.ui.ScreenBase)
    public function new() {
		_eventMap = new Map<String, UIEvent->Void>();
        _mutationObserver = new MutationObserver(onMutationEvent);
        _mutationObserver.observe(Screen.instance.container, { childList: true });
	}
	
    private function onMutationEvent(r:Array<MutationRecord>, o:MutationObserver) {
        recursiveReady();
    }
    
    private function recursiveReady() {
        if (_mutationObserver != null) {
            _mutationObserver.disconnect();
            _mutationObserver = null;
        }
        var component:Component = cast(this, Component);
        component.ready();
        for (child in component.childComponents) {
            child.recursiveReady();
        }
    }
    
	public function handleCreate(native:Bool) {
		var newElement = null;
		if (native == true) {
			var className = Type.getClassName(Type.getClass(this));
			if (className == "haxe.ui.containers.ScrollView") { // special case for scrollview
				_nativeElement = new NativeElement(cast this);
				if (element == null) {
					element = _nativeElement.create();
				}
				element.style.position = "absolute";
				element.style.overflow = "auto";
				return;
			} else {
				var nativeConfig:GenericConfig = Toolkit.backendConfig.findBy("native");
				if (nativeConfig != null) {
					var componentConfig:GenericConfig = nativeConfig.findBy("component", "id", className);
					if (componentConfig != null) {
						var nativeComponentClass:String = componentConfig.values.get("class");
						_nativeElement = Type.createInstance(Type.resolveClass(nativeComponentClass), [this]);
						_nativeElement.config = componentConfig.values;
						newElement = _nativeElement.create();
					}
				}
			}

			if (newElement != null) {
				newElement.style.position = "absolute";
				
				if (element != null) {
					var p = element.parentElement;
					if (p != null) {
						p.replaceChild(newElement, element);
					}
				}
				
				element = newElement;
				
                remapEvents();
			}
		} 
		
		if (newElement == null) {
			if (Type.getClassName(Type.getClass(this)) == "haxe.ui.containers.ScrollView") {
				_nativeElement = null;
				if (element == null) {
					element = Browser.document.createDivElement();
					element.style.setProperty("-webkit-touch-callout", "none");
					element.style.setProperty("-webkit-user-select", "none");
					element.style.setProperty("-khtml-user-select", "none");
					element.style.setProperty("-moz-user-select", "none");
					element.style.setProperty("-ms-user-select", "none");
					element.style.setProperty("user-select", "none");
					element.style.position = "absolute";
				}
				
				
                element.scrollTop = 0;
                element.scrollLeft = 0;
                element.style.overflow = "hidden";
				return;
			}
			
			newElement = Browser.document.createDivElement();
			
			newElement.style.setProperty("-webkit-touch-callout", "none");
			newElement.style.setProperty("-webkit-user-select", "none");
			newElement.style.setProperty("-khtml-user-select", "none");
			newElement.style.setProperty("-moz-user-select", "none");
			newElement.style.setProperty("-ms-user-select", "none");
			newElement.style.setProperty("user-select", "none");
			newElement.style.position = "absolute";
			
			if (element != null) {
				var p = element.parentElement;
				if (p != null) {
					p.replaceChild(newElement, element);
				}
			}
			
			element = newElement;
			_nativeElement = null;

            remapEvents();
		}
	}
	
    private function remapEvents():Void {
        if (_eventMap == null) {
            return;
        }
        var copy:Map <String, UIEvent->Void> = new Map<String, UIEvent->Void>();
        for (k in _eventMap.keys()) {
            var fn = _eventMap.get(k);
            copy.set(k, fn);
            unmapEvent(k, fn);
        }
        _eventMap = new Map<String, UIEvent->Void>();
        for (k in copy.keys()) {
            mapEvent(k, copy.get(k));
        }
    }
    
    private function handlePosition(left:Null<Float>, top:Null<Float>, style:Style):Void {
        if (element == null) {
            return;
        }
        
        if (left != null) {
    		element.style.left = HtmlUtils.px(left);
        }
        if (top != null) {
    		element.style.top = HtmlUtils.px(top);
        }
    }
    
    private function handleSize(width:Null<Float>, height:Null<Float>, style:Style) {
        if (width == null || height == null || width <= 0 || height <= 0) {
            return;
        }
        
        if (this.element == null) {
            return;
        }
        
        if (Std.is(this, VProgress)) { // this is a hack for chrome
            if (element.style.getPropertyValue("transform-origin") != null && element.style.getPropertyValue("transform-origin").length > 0) {
                var tw = width;
                var th = height;
                
                width = th;
                height = tw;
            }
        }
        
        
		var css:CSSStyleDeclaration = element.style;
        StyleHelper.apply(this, width, height, style);
        
        var parent:ComponentBase = cast(this, Component).parentComponent;
		if (parent != null && parent.element.style.borderWidth != null) {
			css.marginTop = '-${parent.element.style.borderWidth}';
			css.marginLeft = '-${parent.element.style.borderWidth}';
		} else {
        }
        
        for (child in cast(this, Component).childComponents) {
            if (style.borderLeftSize != null && style.borderLeftSize > 0) {
                child.element.style.marginLeft = '-${style.borderLeftSize}px';
            }
            if (style.borderTopSize != null && style.borderTopSize > 0) {
                child.element.style.marginTop = '-${style.borderTopSize}px';
            }
        }
    }
    
    private function handleReady() {
        
    }
    
    private function handleClipRect(value:Rectangle):Void {
        var parent:ComponentBase = cast(this, Component).parentComponent;
        if (parent._nativeElement == null) {
            element.style.clip = 'rect(${HtmlUtils.px(value.top)},${HtmlUtils.px(value.right)},${HtmlUtils.px(value.bottom)},${HtmlUtils.px(value.left)})';
            element.style.left = '${HtmlUtils.px(-value.left + 0)}';
            element.style.top = '${HtmlUtils.px(-value.top + 0)}';
        } else {
            element.style.removeProperty("clip");
        }
    }
    
    public function handlePreReposition():Void {
    }
    
    public function handlePostReposition():Void {
    }
    
    private function handleVisibility(show:Bool):Void {
        element.style.display = (show == true) ? "" : "none";
    }

	//***********************************************************************************************************
	// Text related
	//***********************************************************************************************************
	private var _textDisplay:TextDisplay;
	public function createTextDisplay(text:String = null):TextDisplay {
		if (_textDisplay == null) {
			_textDisplay = new TextDisplay();
			_textDisplay.parentComponent = cast this;
			element.appendChild(_textDisplay.element);
		}
		if (text != null) {
			_textDisplay.text = text;
		}
		return _textDisplay;
	}
	
	public function getTextDisplay():TextDisplay {
		return createTextDisplay();
	}
	
	public function hasTextDisplay():Bool {
		return (_textDisplay != null);
	}

	private var _textInput:TextInput;
	public function createTextInput(text:String = null):TextInput {
		if (_textInput == null) {
			_textInput = new TextInput();
			_textInput.parentComponent = cast this;
			element.appendChild(_textInput.element);
		}
		if (text != null) {
			_textInput.text = text;
		}
		return _textInput;
	}
	
	public function getTextInput():TextInput {
		return createTextInput();
	}
	
	public function hasTextInput():Bool {
		return (_textInput != null);
	}
	
	//***********************************************************************************************************
	// Image related
	//***********************************************************************************************************
	private var _imageDisplay:ImageDisplay;
	public function createImageDisplay():ImageDisplay {
		if (_imageDisplay == null) {
			_imageDisplay = new ImageDisplay();
			element.appendChild(_imageDisplay.element);
		}
		return _imageDisplay;
	}
	
	public function getImageDisplay():ImageDisplay {
		return createImageDisplay();
	}
	
	public function hasImageDisplay():Bool {
		return (_imageDisplay != null);
	}
	
	public function removeImageDisplay():Void {
		if (_imageDisplay != null) {
			/*
			if (contains(_imageDisplay) == true) {
				removeChild(_imageDisplay);
			}
			*/
			_imageDisplay.dispose();
			_imageDisplay = null;
		}
	}
	
	//***********************************************************************************************************
	// Display tree
	//***********************************************************************************************************
	private function handleAddComponent(child:Component):Component {
		element.appendChild(child.element);
		return child;
	}

	private function handleRemoveComponent(child:Component, dispose:Bool = true):Component {
        HtmlUtils.removeElement(child.element);
		return child;
	}

	private function applyStyle(style:Style) {
        if (element == null) {
            return;
        }
        
		var useHandCursor = false;
		if (style.cursor != null && style.cursor == "pointer") {
			useHandCursor = true;
		}

        setCursor(useHandCursor == true ? "pointer" : null);

		if (style.filter != null) {
            if (style.filter[0] == "drop-shadow") {
                var dropShadow:DropShadow = FilterParser.parseDropShadow(style.filter);
                if (dropShadow.inner == false) {
                    element.style.boxShadow = '${dropShadow.distance}px ${dropShadow.distance}px ${dropShadow.blurX}px 0px ${HtmlUtils.rgba(dropShadow.color, dropShadow.alpha)}';
                } else {
                    element.style.boxShadow = 'inset ${dropShadow.distance}px ${dropShadow.distance}px ${dropShadow.blurX}px 0px ${HtmlUtils.rgba(dropShadow.color, dropShadow.alpha)}';
                }
            } else if (style.filter[0] == "blur") {
                trace(style.filter);
                var blur:Blur = FilterParser.parseBlur(style.filter);
                element.style.setProperty("-webkit-filter", 'blur(1px)');
                element.style.setProperty("-moz-filter", 'blur(1px)');
                element.style.setProperty("-o-filter", 'blur(1px)');
                //element.style.setProperty("-ms-filter", 'blur(1px)');
                element.style.setProperty("filter", 'blur(1px)');
            }
		} else {
			element.style.boxShadow = null;
			element.style.removeProperty("box-shadow");
            element.style.removeProperty("-webkit-filter");
            element.style.removeProperty("-moz-filter");
            element.style.removeProperty("-o-filter");
            //element.style.removeProperty("-ms-filter");
            element.style.removeProperty("filter");
		}
		
        if (style.opacity != null) {
            element.style.opacity = '${style.opacity}';
        }
	}
	
	//***********************************************************************************************************
	// Util functions
	//***********************************************************************************************************
    private function setCursor(cursor:String) {
        if (cursor == null) {
            cursor = "default";
        }
        if (cursor == null) {
            element.style.removeProperty("cursor");
            if (hasImageDisplay()) {
                getImageDisplay().element.style.removeProperty("cursor");
            }
            if (hasTextDisplay()) {
                getTextDisplay().element.style.removeProperty("cursor");
            }
            if (hasTextInput()) {
                //getTextInput().element.style.removeProperty("cursor");
            }
        } else {
            element.style.cursor = cursor;
            if (hasImageDisplay()) {
                getImageDisplay().element.style.cursor = cursor;
            }
            if (hasTextDisplay()) {
                getTextDisplay().element.style.cursor = cursor;
            }
            if (hasTextInput()) {
                //getTextInput().element.style.cursor = cursor;
            }
        }
        
        for (c in cast(this, Component).childComponents) {
            c.setCursor(cursor);
        }
    }
	
	//***********************************************************************************************************
	// Events
	//***********************************************************************************************************
	private function mapEvent(type:String, listener:UIEvent->Void) {
		switch (type) {
			case MouseEvent.MOUSE_MOVE | MouseEvent.MOUSE_OVER | MouseEvent.MOUSE_OUT
				| MouseEvent.MOUSE_DOWN | MouseEvent.MOUSE_UP | MouseEvent.CLICK:
				if (_eventMap.exists(type) == false) {
					_eventMap.set(type, listener);
					element.addEventListener(EventMapper.HAXEUI_TO_DOM.get(type), __onMouseEvent);
				}
			case MouseEvent.MOUSE_WHEEL:
                _eventMap.set(type, listener);
                if (UserAgent.instance.firefox == true) {
                    element.addEventListener("DOMMouseScroll", __onMouseWheelEvent);
                } else {
                    element.addEventListener("mousewheel", __onMouseWheelEvent);
                }
		}
	}
	
	private function unmapEvent(type:String, listener:UIEvent->Void) {
		switch (type) {
			case MouseEvent.MOUSE_MOVE | MouseEvent.MOUSE_OVER | MouseEvent.MOUSE_OUT
				| MouseEvent.MOUSE_DOWN | MouseEvent.MOUSE_UP | MouseEvent.CLICK:
				_eventMap.remove(type);
				element.removeEventListener(EventMapper.HAXEUI_TO_DOM.get(type), __onMouseEvent);
			
            case MouseEvent.MOUSE_WHEEL:
				_eventMap.remove(type);
                if (UserAgent.instance.firefox == true) {
                    element.removeEventListener("DOMMouseScroll", __onMouseWheelEvent);
                } else {
                    element.removeEventListener("mousewheel", __onMouseWheelEvent);
                }
		}
	}
	
	//***********************************************************************************************************
	// Event Handlers
	//***********************************************************************************************************
	private function __onMouseEvent(event:js.html.MouseEvent) {
		var type:String = EventMapper.DOM_TO_HAXEUI.get(event.type);
        //trace(type + ", " + event.target);
		if (type != null) {
			var fn = _eventMap.get(type);
			if (fn != null) {
				var mouseEvent = new MouseEvent(type);
				mouseEvent.screenX = event.pageX;
				mouseEvent.screenY = event.pageY;
				fn(mouseEvent);
			}
		}
	}

	private function __onMouseWheelEvent(event:js.html.MouseEvent) {
        var fn = _eventMap.get(MouseEvent.MOUSE_WHEEL);
        if (fn == null) {
            return;
        }
        
        var delta:Float = 0;
        if (Reflect.field(event, "wheelDelta") != null) {
            delta = Reflect.field(event, "wheelDelta");
        } else if (Std.is(event, WheelEvent)) {
            delta = cast(event, WheelEvent).deltaY;
        } else {
            delta = -event.detail;
        }
        
        delta = Math.max(-1, Math.min(1, delta));
        
        var mouseEvent = new MouseEvent(MouseEvent.MOUSE_WHEEL);
        mouseEvent.screenX = event.pageX;
        mouseEvent.screenY = event.pageY;
        mouseEvent.delta = delta;
        fn(mouseEvent);
    }
}