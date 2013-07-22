require 'spec_helper'

describe "BrochureSpecs" do
  sbf_link = 'http://esales.hdb.gov.sg/hdbvsf/eampu05p.nsf/3ccada7e5293fd9748256e990029b104/13MAYSBF_page_5789/$file/about0_static.htm'
  details_dropdown = "//div[@id='MenuBoxTop']//a[contains(@class,'t7')]"
  price_dropdown = "//div[@id='MenuBoxTop']//a[contains(@class,'t8')]"

  block_fields = [:no, :street, :probable_date, :delivery_date, :lease_start, :ethnic_quota, :estate_id]
  unit_fields = [:price, :area, :flat_type]

  def find_block_info(item)
    text = item.split[0]
    page.find(:xpath, "//td[@class='textLabelNew' and contains(.,'#{text}')]/following-sibling::td[1]").text
  end

  before do
    visit sbf_link
    sleep 1
  end

  it "load details page" do
    Estate.all.each do |estate|
      puts "Estate: #{estate.name}"

      next if estate.units.count == estate.total

      while all('#titletwn', text: estate.name).count == 0 do
        within('div#cssdrivemenu1') do
          while true
            dropdown = page.all(:xpath, details_dropdown)

            if dropdown.count > 0
              dropdown.first.trigger(:mouseover)
              break
            end
          end

          link = find_link(estate)
          # link['onclick'].should == "goFlats('../../13MAYSBF_page_5789/$file/map.htm?open&ft=sbf&twn=GL')"

          link.click
        end
      end

      within_frame 'fda' do
        flat_types = page.all(:xpath, "//select[@name='Flat']/option")
        # flat_types.count.should == 5

        flat_types.map(&:text).each do |flat_type|
          puts "Type: #{flat_type}"
          select flat_type, from: 'select7'

          click_button 'Search'
          sleep 3

          within_frame 'search' do
            # block_nos = page.all(:xpath, "//strong[contains(.,'Click on block no')]/ancestor::tr[1]/following-sibling::tr//a")
            block_divs = page.all(:xpath, "//strong[contains(.,'Click on block no')]/ancestor::tr[1]/following-sibling::tr//a/div")

            block_links = block_divs.map do |b|
              id = b[:id]
              no = page.find(:xpath, "//div[@id='#{id}']/ancestor::a[1]")
              street = page.find(:xpath, "//div[@id='#{id}']//font").text
              [no.text(:visible), street, no[:href]]
            end

            puts "Blocks: #{block_links.count}"

            block_links.each do |link|
              puts link[1], link.last

              expected_state = %Q{
                //strong[contains(.,'Click on block no')]/ancestor::tr[1]/following-sibling::tr
                //b[contains(.,'#{link.first}')]
                //font[contains(.,\"#{link[1]}\")]
              }

              while all(:xpath, expected_state).count == 0
                page.execute_script(link.last)
              end

              block_info = ['Block','Street','Probable Completion Date', 'Delivery Possession Date',
                'Lease Commencement Date', 'Available Ethnic Quota'].map do |item|
                # puts "#{item}: #{find_block_info(item)}"
                find_block_info(item)
              end << estate.id

              block_hash = Hash[block_fields.zip(block_info)]
              block = Block.where(no: block_hash[:no], street: block_hash[:street]).first_or_create(block_hash)

              unit_nos = page.all(:xpath, "//td[contains(.,'Mouseover unit number')]/ancestor::table[1]/following-sibling::table//font")
              puts "Units: #{unit_nos.count}"

              unit_nos.map(&:text).each do |unit|
                unit_info = page.all(:xpath, "//font[contains(.,'#{unit}')]/ancestor::td[1]/div[1]//td")
                                .map(&:text) << flat_type

                unit_hash = Hash[unit_fields.zip(unit_info)]
                unit = Unit.where(no: unit, block: block).first_or_create(unit_hash)
                p unit_info
              end
            end
          end
        end
      end
    end
  end

  it 'loads intro page' do
    pending 'already parsed flat supply numbers'

    estates = page.all(:xpath, "//div[@id='cssdrivemenu2']//a").map(&:text)

    # puts estates.count
    # puts estates.map(&:text)
    estates.each do |estate|
      while all(:xpath, "//font[@color='#6FD6D9' and contains(normalize-space(text()), '#{estate}')]").count == 0 do
        within('div#cssdrivemenu2') do
          while true
            dropdown = page.all(:xpath, price_dropdown)

            if dropdown.count > 0
              dropdown.first.trigger(:mouseover)
              break
            end
          end

          link = find_link(estate)
          link.click
        end
      end

      supply = page.all(:xpath, "//tr[@bgcolor='#FFFFFF']/td[2]").map(&:text).map(&:to_i).inject(:+)
      puts "#{estate}: #{supply}"

      Estate.where(name: estate).first_or_create(total: supply)
    end
  end
end
