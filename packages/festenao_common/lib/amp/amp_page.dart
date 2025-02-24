import 'dart:convert';

import 'package:tekartik_common_utils/env_utils.dart';
import 'package:tekartik_html/html_html5lib.dart';
import 'package:tekartik_yacht/yacht.dart';
import 'package:tekartik_yacht/yacht_mvp.dart';

dynamic sanitize(dynamic value) {
  if (value is String || value is num || value is bool || value == null) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) =>
        MapEntry<String, dynamic>(key as String, sanitize(value)));
  }
  if (value is List) {
    return value.map((value) => sanitize(value));
  }
  return value.toString();
}

class FestenaoAmpPage {
  Future<String> build() async {
    var htmlProvider = htmlProviderHtml5Lib;

    var index = htmlProvider.createDocument(title: 'Amp Yacht example');
    var body = index.body;
    var html = index.html;
    html.setAttribute('⚡', '');

    var head = index.head;
    var children = htmlProvider.createNodesHtml(
      yachtAmpBoilerplate,
      noValidate: true,
    );
    //print(children);

    for (var child in List.of(children)) {
      //print(child);
      head.appendChild(child);
      //head.appendChild(htmlProvider.createTextNode('\n'));
    }
    head.appendLf();
    head.appendElementTag('style')
      ..attributes['amp-custom'] = ''
      ..text = cssMvpMin;
    head.appendLf();
    var main = htmlProvider.createElementTag('main');
    main
      ..appendElementHtml('<h1>Amp Yacht example</h1>')
      ..appendLf();

    body
      ..appendChild(main)
      ..appendLf();
    void appUlToBody() {
      var ul = htmlProvider.createElementTag('ul');
      main.appendChild(ul);

      var li = htmlProvider.createElementTag('li');

      if (isDebug) {
        ul.appendChild(li);
        li.appendChild(
          htmlProvider.createElementHtml('<a href="#">#normal</a>'),
        );
        ul.appendChild(htmlProvider.createTextNode('\n'));

        li = htmlProvider.createElementTag('li');
        ul.appendChild(li);
        li.appendChild(
          htmlProvider.createElementHtml(
            '<a href="#development=1">#development=1</a>',
          ),
        );
        li = htmlProvider.createElementTag('li');
        ul.appendChild(li);
        li.appendChild(
          htmlProvider.createElementHtml(
            '<a href="..">Up</a>',
          ),
        );
      }
      ul.appendChild(htmlProvider.createTextNode('\n'));
    }

    void applyConsole() {
      if (_console.isNotEmpty) {
        var pre = main.appendElementTag('pre');
        pre.appendElementTag('samp').text = _console.join('\n');
        pre.appendLf();
        main.appendLf();
      }
    }

    if (isDebug) {
      appUlToBody();
      applyConsole();
      // ignore: dead_code
      if (false) {
        main.appendNodesHtml('''
      <header>
    <nav>
        <a href="/"><img alt="Logo" src="https://via.placeholder.com/200x70?text=Logo" height="70"></a>
        <ul>
            <li>Menu Item 1</li>
            <li><a href="#section-1">Menu Item 2</a></li>
            <li><a href="#">Dropdown Menu Item</a>
                <ul>
                    <li><a href="#">Sublink with a long name</a></li>
                    <li><a href="#">Short sublink</a></li>
                </ul>
            </li>
        </ul>
    </nav>
    <h1>Page Heading with <i>Italics</i> and <u>Underline</u></h1>
    <p>Page Subheading with <mark>highlighting</mark></p>
    <br>
    <p><a href="#"><i>Italic Link Button</i></a><a href="#"><b>Bold Link Button &rarr;</b></a></p>
</header>
<main>
    <hr>
    <section id="section-1">
        <header>
            <h2>Section Heading</h2>
            <p>Section Subheading</p>
        </header>
        <aside>
            <h3>Card heading</h3>
            <p>Card content*</p>
            <p><small>*with small content</small></p>
        </aside>
        <aside>
            <h3>Card heading</h3>
            <p>Card content <sup>with notification</sup></p>
        </aside>
        <aside>
            <h3>Card heading</h3>
            <p>Card content</p>
        </aside>
    </section>
    <hr>
    <section>
        <blockquote>
            "Quote"
            <footer><i>- Attribution</i></footer>
        </blockquote>
    </section>
    <hr>
    <section>
        <table>
            <thead>
            <tr>
                <th></th>
                <th>Col A</th>
                <th>Col B</th>
                <th>Col C</th>
            </tr>
            </thead>
            <tr>
                <td>Row 1</td>
                <td>Cell A1</td>
                <td>Cell B1</td>
                <td>Cell C1</td>
            </tr>
            <tr>
                <td>Row 2</td>
                <td>Cell A2</td>
                <td>Cell B2</td>
                <td>Cell C2</td>
            </tr>
        </table>
    </section>
    <hr>
    <article>
        <h2>Left-aligned header</h2>
        <p>Left-aligned paragraph</p>
        <aside>
            <p>Article callout</p>
        </aside>
        <ul>
            <li>List item 1</li>
            <li>List item 2</li>
        </ul>
        <figure>
            <img alt="Stock photo" src="https://via.placeholder.com/1080x500?text=Amazing+stock+photo">
            <figcaption><i>Image caption</i></figcaption>
        </figure>
    </article>
    <hr>
    <div>
        <details>
            <summary>Expandable title</summary>
            <p>Revealed content</p>
        </details>
        <details>
            <summary>Another expandable title</summary>
            <p>More revealed content</p>
        </details>
        <br>
        <p>Inline <code>code</code> snippets</p>
        <pre>
                <code>
// preformatted code block
                </code>
            </pre>
    </div>
    <hr>
    <section>
        <form>
            <header>
                <h2>Form title</h2>
            </header>
            <label for="input1">Input label:</label>
            <input type="text" id="input1" name="input1" size="20" placeholder="Input1">
            <label for="select1">Select label:</label>
            <select id="select1">
                <option value="option1">option1</option>
                <option value="option2">option2</option>
            </select>
            <label for="textarea1">Textarea label:</label>
            <textarea cols="40" rows="5" id="textarea1"></textarea>
            <button type="submit">Submit</button>
        </form>
    </section>
</main>
<footer>
    <hr>
    <p>
        <small>Contact info</small>
    </p>
</footer>
''');
      }
    }
    var result = htmlPrintDocument(
      index,
      options: HtmlPrinterOptions(),
    );

    // print(result);
    return result;
    /*
  var inputDir = Directory(join('example', 'input'));
  var files = await inputDir
      .list()
      .map((fse) => basename(fse.path))
      .where((name) => extension(name) == '.html')
      .toList();
  var outputDir = Directory(join('example', 'output'));
  await outputDir.create(recursive: true);
  for (var file in files) {
    await tidyHtml(
        srcFilePath: join(inputDir.path, file),
        dstFilePath: join(outputDir.path, file));
  }*/
  }

  final _console = <String>[];
  void consoleAdd(String text) {
    var lines = LineSplitter.split(text);
    _console.addAll(lines);
  }
}
/*
Map<String, dynamic> cmsArticleMap(CmsArticle article) {
  var map = <String, dynamic>{};
  map['title'] = article.title;
  map['summary'] = article.summary;
  return map;
  // return sanitize(article.toDocumentData().asMap()) as Map<String, dynamic>;
}

class AmpListPage {
  final FileSystem fs;
  List<CmsArticle> articles;

  AmpListPage({required this.fs, required this.articles});
  Future<String?> toHtmlText() async {
    var values = <String, dynamic>{};
    values['title'] = 'All posts';
    values['articles'] =
        articles.map((article) => cmsArticleMap(article)).toList();
    print(values);
    return await renderFile(fs, fs.path.join('deploy', 'amp', 'index.html'),
        values: values);
  }
}
*/
