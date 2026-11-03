import 'dart:async';
import 'dart:js_interop';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

final _scopes = <String>{};
final _fields = <String, _Credential>{};
final _observers = <web.Node, web.MutationObserver>{};
bool _scheduled = false;

/// Observe structure and credential attributes only, not layout/style changes.
/// There is no polling, network call, storage, logging or focus manipulation.
void _schedule() {
  if (_scheduled || _scopes.isEmpty) return;
  _scheduled = true;
  scheduleMicrotask(() {
    _scheduled = false;
    if (_scopes.isNotEmpty) _refresh();
  });
}

List<web.Node> _roots() {
  final roots = <web.Node>[web.document];
  final views = web.document.querySelectorAll('flutter-view, flt-glass-pane');
  for (var i = 0; i < views.length; i++) {
    final shadow = (views.item(i) as web.Element).shadowRoot;
    if (shadow != null) roots.add(shadow);
  }
  return roots;
}

web.Element? _query(web.Node root, String selector) => root == web.document
    ? web.document.querySelector(selector)
    : (root as web.ShadowRoot).querySelector(selector);

void _refresh() {
  final roots = _roots();
  for (final root in roots) {
    final node = root;
    _observers.putIfAbsent(node, () {
      final observer = web.MutationObserver(
        ((JSArray<web.MutationRecord> _, web.MutationObserver __) =>
                _schedule())
            .toJS,
      );
      observer.observe(
        node,
        web.MutationObserverInit(
          childList: true,
          subtree: true,
          attributes: true,
          attributeFilter: [
            'id',
            'name',
            'autocomplete',
            'type',
          ].map((s) => s.toJS).toList().toJS,
        ),
      );
      return observer;
    });
  }
  for (final field in _fields.values) {
    web.HTMLInputElement? input;
    if (_scopes.contains(field.scope)) {
      for (final root in roots) {
        final wrapper = _query(
          root,
          '[flt-semantics-identifier="${field.id}"]',
        );
        final candidate = wrapper?.tagName == 'INPUT'
            ? wrapper
            : wrapper?.querySelector('input');
        if (candidate != null) {
          input = candidate as web.HTMLInputElement;
          break;
        }
      }
    }
    field.bind(input);
  }
}

void setCredentialScope(String id, bool active) {
  if (active) {
    _scopes.add(id);
    _schedule();
  } else {
    _scopes.remove(id);
    for (final field in _fields.values.where((field) => field.scope == id)) {
      field.bind(null);
    }
    if (_scopes.isEmpty) {
      for (final observer in _observers.values) {
        observer.disconnect();
      }
      _observers.clear();
    }
  }
}

void registerCredential(
  String id,
  String scope,
  TextEditingController controller,
  String name,
  String autocomplete,
  String type,
) {
  final field = _fields[id];
  if (field != null && field.controller == controller) {
    field.scope = scope;
    field.name = name;
    field.autocomplete = autocomplete;
    field.type = type;
  } else {
    field?.dispose();
    _fields[id] = _Credential(id, scope, controller, name, autocomplete, type);
  }
  _schedule();
}

void unregisterCredential(String id) => _fields.remove(id)?.dispose();
void syncCredentials() {
  for (final field in _fields.values) {
    field.read();
  }
}

class _Credential {
  final String id;
  String scope, name, autocomplete, type;
  final TextEditingController controller;
  web.HTMLInputElement? element;
  late final JSFunction _input = ((web.Event _) {
    if (element?.matches(':focus') ?? false) {
      // Let Flutter's active editor process selection and IME composition first.
      // Only reconcile afterwards if that editor did not receive the value.
      scheduleMicrotask(read);
    } else {
      read();
    }
  }).toJS;

  _Credential(
    this.id,
    this.scope,
    this.controller,
    this.name,
    this.autocomplete,
    this.type,
  ) {
    controller.addListener(_write);
  }

  void bind(web.HTMLInputElement? input) {
    if (input != element) {
      element?.removeEventListener('input', _input);
      element?.removeEventListener('change', _input);
      element = input;
      if (input != null) {
        input.addEventListener('input', _input);
        input.addEventListener('change', _input);
        _write();
      }
    }
    if (input == null) return;
    for (final entry in {
      'id': id,
      'name': name,
      'autocomplete': autocomplete,
      'type': type,
    }.entries) {
      if (input.getAttribute(entry.key) != entry.value)
        input.setAttribute(entry.key, entry.value);
    }
  }

  void read() {
    final input = element;
    if (input == null ||
        !input.isConnected ||
        input.disabled ||
        input.readOnly ||
        !_scopes.contains(scope))
      return;
    final value = input.value;
    if (value != controller.text) {
      controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  void _write() {
    final input = element;
    if (input != null && input.value != controller.text)
      input.value = controller.text;
  }

  void dispose() {
    bind(null);
    controller.removeListener(_write);
  }
}
