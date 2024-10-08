require 'open-uri'
require 'zip'
require 'csv'

# zipをダウンロードする
def download_zip(url, download_dir, zip_filename)
  zip_filepath = File.join(download_dir, zip_filename)
  Dir.mkdir(download_dir) unless Dir.exist?(download_dir)

  File.open(zip_filepath, "wb") do |saved_file|
    URI.open(url, "rb") do |read_file|
      saved_file.write(read_file.read)
    end
  end

  puts "*********************************************"
  puts "*********************************************"
  puts "LOG::Downloaded #{zip_filename} to #{zip_filepath}"
  puts "*********************************************"
  puts "*********************************************"
  zip_filepath
end

# zipを解凍する
def extract_zip(zip_filepath, extract_dir)
  Dir.mkdir(extract_dir) unless Dir.exist?(extract_dir)

  Zip::File.open(zip_filepath) do |zip_file|
    zip_file.each do |entry|
      entry_path = File.join(extract_dir, entry.name)
      FileUtils.mkdir_p(File.dirname(entry_path))
      zip_file.extract(entry, entry_path) unless File.exist?(entry_path)
      puts "*********************************************"
      puts "*********************************************"
      puts "LOG::Extracted #{entry.name} to #{entry_path}"
      puts "*********************************************"
      puts "*********************************************"
    end
  end
end

# 全角スペースを半角スペースに変換
def replace_fullwidth_space(text)
  text.gsub('　', ' ')
end

# 郵便番号の整形：0が省略されている場合に付与
def format_postal_code(postal_code)
  postal_code.rjust(7, '0')  # 7桁に満たない場合、0を付ける
end

def process_csv(csv_file_path)
  concatenated_addresses = []

  CSV.foreach(csv_file_path, headers: false, col_sep: ",", quote_char: "\"", encoding: "Shift_JIS:UTF-8", liberal_parsing: true) do |row|
    postal_code = format_postal_code(row[0])
    kanji_address = replace_fullwidth_space(concat_kanji_address(row))
    romaji_address = replace_fullwidth_space(concat_romaji_address(row))
    concatenated_addresses << { postal_code: postal_code, kanji_address: kanji_address, romaji_address: romaji_address }
  end

  concatenated_addresses
end

def concat_kanji_address(row)
  "#{row[1]} #{row[2]} #{row[3]}".strip
end

def remove_unwanted_romaji_parts(raw_romaji)
  unwanted_parts = ["TO", "FU", "KEN", "SHI", "KU", "CHO", "GUN", "MURA"]
  raw_romaji.split(" ").reject { |part| unwanted_parts.include?(part) }.join(" ")
end

def concat_romaji_address(row)
  # ローマ字の住所部分を結合し、不要な部分を除外
  raw_romaji = "#{row[4]} #{row[5]} #{row[6]}".strip
  remove_unwanted_romaji_parts(raw_romaji)
end

# 指定された郵便番号と市区町村名から漢字部分のインデックスを取得する
def find_romaji_by_city_and_postal_code(processed_data, postal_code, city_name)
  filtered_data = processed_data.select { |entry| entry[:postal_code] == postal_code }
  filtered_data.each do |entry|
    kanji_parts = entry[:kanji_address].split(" ")
    romaji_parts = entry[:romaji_address].split(" ")

    # 指定された市区町村名がどの部分に含まれているかを検索
    kanji_index = kanji_parts.find_index { |part| part.include?(city_name) }
    if kanji_index

      puts "*********************************************"
      puts "Found '#{city_name}' in kanji_parts at index: #{kanji_index}"
      puts "kanji_parts:'#{kanji_parts}'"
      puts "romaji_parts:'#{romaji_parts}'"
      puts "*********************************************"

      case kanji_index
      when 0
        puts "漢字インデックスは0なので都道府県です。"
        return romaji_parts[0].downcase
      when 1
        puts "漢字インデックス1"
        return romaji = romaji_parts[1].downcase 
      when 2
        puts "漢字インデックス2"
        return romaji = romaji_parts[2].downcase
      when 3
        puts "漢字インデックス3"
        return romaji = romaji_parts[3].downcase
      when 4
        puts "漢字インデックス4"
        return romaji = romaji_parts[4].downcase
      end

      return romaji
    end

  end
  puts "*********************************************"
  puts "NotFound:kanji_index for #{city_name} with postal code #{postal_code}"
  puts "*********************************************"
  nil # 該当する市区町村名が見つからなかった場合
end

def main
  # (1)zipをダウンロードする
  url = "https://www.post.japanpost.jp/zipcode/dl/roman/KEN_ALL_ROME.zip"
  download_dir = "./downloads"
  zip_filename = "ken_all.zip"
  zip_filepath = download_zip(url, download_dir, zip_filename)

  # (2)zipを解凍する
  extract_dir = "./extracted_files"
  extract_zip(zip_filepath, extract_dir)


  # (3)解凍されたCSVファイルのパスを指定する
  csv_file_path = File.join(extract_dir, 'KEN_ALL_ROME.csv') # 実際のファイル名に変更してください

  # (4)csvのデータを加工する
  processed_data = process_csv(csv_file_path)
  if processed_data.empty?
    return puts "processed_data is empty"
  end 

  # ログ
  # p processed_data

  # (5)配列の中から指定した市区町村名の漢字インデックスを取得する
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # [[[[[[[[[[[[[[[[[[[[[[[WORNING]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]]
  # 0が省略されている郵便番号に気をつけること
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
  postal_code = "0800833" # 例として郵便番号を指定
  city_name = "基線" # 例として市区町村名を指定
  romaji = find_romaji_by_city_and_postal_code(processed_data, postal_code, city_name)

  # (FINAL)成功したメッセージを表示する
  puts "ローマ字は『#{romaji}』です"
  puts "process csv successly"
end

# main関数を実行する
main