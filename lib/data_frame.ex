
defmodule DataFrame do
  @moduledoc """
    Functions to create and modify a Frame, a structure with a 2D table with information, indexes and columns
  """
  alias DataFrame.Table
  alias DataFrame.Frame

  @doc """
    Creates a new Frame from a 2D table, It creates a numeric index and a numeric column array automatically.
  """
  def new(table) when is_list(table) do
    values = Table.new(table)
    index = autoindex_for_table_dimension(values, 0)
    columns = autoindex_for_table_dimension(values, 1)
    new(values, columns, index)
  end

  @doc """
    Creates a new Frame from a 2D table, and a column array. It creates a numeric index automatically.
  """
  def new(table, columns) when is_list(table) and is_list(columns) do
    values = Table.new(table)
    index = autoindex_for_table_dimension(values, 0)
    new(values, columns, index)
  end

  @doc """
    Creates a new Frame from a 2D table, an index and a column array
  """
  def new(table, columns, index) when is_list(table) and is_list(index) and is_list(columns) do
    values = Table.new(table)
    Table.check_dimensional_compatibility!(values, index, 0)
    Table.check_dimensional_compatibility!(values, columns, 1)
    %Frame{values: values, index: index, columns: columns}
  end

  defp autoindex_for_table_dimension(table, dimension) do
    table_dimension = table |> Table.dimensions |> Enum.at(dimension)
    if table_dimension == 0 do
      []
    else
      Enum.to_list 0..table_dimension - 1
    end
  end

  @doc """
    Creates a Frame from the textual output of a frame (allows copying data from webpages, etc.)
  """
  def parse(text) do
    [header | data ] = String.split(text, "\n", trim: true)
    columns = String.split(header, " ", trim: true)
    data_values = Enum.map(data, &(String.split(&1, " ", trim: true)))
    [values, index] = Table.remove_column(data_values, 0, return_column: true)
    values_data = Table.map(values, &transform_type/1)
    columns_data = Enum.map(columns, &transform_type/1)
    index_data = Enum.map(index, &transform_type/1)
    new(values_data, columns_data, index_data)
  end

  # TODO: Refactor, probably this is the most non-Elixir code even written
  defp transform_type(element) do
    int = Integer.parse(element)
    if int == :error or (elem(int, 1) != "") do
      float = Float.parse(element)
      if float == :error or (elem(float, 1) != "") do
        element
      else
        elem(float, 0)
      end
    else
      elem(int, 0)
    end
  end

  # ##################################################
  #  Ordering
  # ##################################################

  @doc """
    Returns a Frame which data has been transposed.
  """
  def transpose(frame) do
    %Frame{values: Table.transpose(frame.values), index: frame.columns, columns: frame.index}
  end

  @doc """
    Sorts the data in the frame based on its index. By default the data is sorted in ascending order.
  """
  def sort_index(frame, ascending \\ true) do
    sort(frame, 0, ascending)
  end

  @doc """
    Sorts the data in the frame based on a given column. By default the data is sorted in ascending order.
  """
  def sort_values(frame, column_name, ascending \\ true) do
    index = Enum.find_index(frame.columns, fn(x) -> x == column_name end)
    sort(frame, index + 1, ascending)
  end

  defp sort(frame, column_index, ascending) do
    sorting_func = if ascending do
      fn(x,y) -> Enum.at(x, column_index) > Enum.at(y, column_index) end
    else
      fn(x,y) -> Enum.at(x, column_index) < Enum.at(y, column_index) end
    end
    [values, index] = frame.values
      |> Table.append_column(frame.index)
      |> Enum.sort(fn(x,y) -> sorting_func.(x,y) end)
      |> Table.remove_column(0, return_column: true)

      DataFrame.new(values, frame.columns, index)
  end

  # ##################################################
  #  Selecting
  # ##################################################

  @doc """
    Returns the information at the top of the frame. Defaults to 5 lines.
  """
  def head(frame, size \\ 5) do
    DataFrame.new(Enum.take(frame.values, size), frame.columns, Enum.take(frame.index, size))
  end

  @doc """
    Returns the information at the bottom of the frame. Defaults to 5 lines.
  """
  def tail(frame, the_size \\ 5) do
    size = -the_size
    head(frame, size)
  end

  def column(frame, column_name) do
    column = Enum.find_index(frame.columns, fn(x) -> to_string(x) == to_string(column_name) end)
    frame.values |> Table.transpose |> Enum.at(column)
  end

  @doc """
    Returns a slice of the data in the frame.
    Parameters are the ranges with names in the index and column
  """
  def loc(frame, index_range, column_range) do
    DataFrame.iloc(frame, index_range_integer(frame, index_range), column_range_integer(frame, column_range))
  end

  defp index_range_integer(_, :all) do
    0..-1
  end

  defp index_range_integer(frame, index_range) do
    index = Enum.find_index(frame.index, fn(x) -> to_string(x) == to_string(Enum.at(index_range, 0)) end)
    index..(index + Enum.count(index_range) - 1)
  end

  defp column_range_integer(_, :all) do
    0..-1
  end

  defp column_range_integer(frame, column_range) do
    column = Enum.find_index(frame.columns, fn(x) -> to_string(x) == to_string(Enum.at(column_range, 0)) end)
    column..(column + Enum.count(column_range) - 1)
  end

  @doc """
    Returns a slice of the data in the frame.
    Parameters are the ranges with positions in the index and column
  """
  def iloc(frame, index, columns) do
    new_index = frame.index |> Enum.slice(index)
    new_columns = frame.columns |> Enum.slice(columns)
    values = frame.values |> Table.slice(index, columns)
    DataFrame.new(values, new_columns, new_index)
  end

  @doc """
    Returns a value located at the position indicated by an index name and column name.
  """
  def at(frame, index_name, column_name) do
    index = Enum.find_index(frame.index, fn(x) -> to_string(x) == to_string(index_name) end)
    column = Enum.find_index(frame.columns, fn(x) -> to_string(x) == to_string(column_name) end)
    DataFrame.iat(frame, column, index)
  end

  @doc """
    Returns a value located at the position indicated by an index position and column position.
  """
  def iat(frame, index, column) do
    Table.at(frame.values, column, index)
  end

  # ##################################################
  #  Mathematics
  # ##################################################

  @doc """
    Returns the cummulative sum
  """
  def cumsum(frame) do
    columns = frame.values |> Table.transpose
    cumsummed = columns |> Enum.map( fn(column) ->
      Enum.flat_map_reduce(column, 0, fn(x, acc) ->
        {[x + acc], acc + x}
      end)
    end)
    data = Enum.map cumsummed, &(elem(&1, 0))
    DataFrame.new(Table.transpose(data), frame.columns, frame.index)
  end

  @doc """
    Returns a statistical description of the data in the frame
  """
  def describe(frame) do
    DataFrame.Statistics.describe(frame)
  end

  # ##################################################
  #  Importing, exporting, plotting
  # ##################################################

  @doc """
    Writes the information of the frame into a csv file. By default the column names are written also
  """
  def to_csv(frame, filename, header \\ true) do
    file = File.open!(filename, [:write])
    values = if (header) do
      [frame.columns | frame.values]
    else
      frame.values
    end
    values |> CSV.encode |> Enum.each(&IO.write(file, &1))
  end

  @doc """
    Reads the information from a CSV file. By default the first row is assumed to be the column names.
  """
  def from_csv(filename) do
    [headers | values] = filename |> File.stream! |> CSV.decode |> Enum.to_list
    new(values, headers)
  end

  def plot(frame) do
    plotter = Explot.new
    columns_with_index = frame.values |> Table.transpose |> Enum.with_index
    Enum.each columns_with_index, fn(column_with_index) ->
      column = elem(column_with_index, 0)
      column_name = Enum.at(frame.columns, elem(column_with_index, 1))
      Explot.add_list(plotter, column, column_name)
    end
    Explot.x_axis_labels(plotter, frame.index)
    Explot.show(plotter)
  end
end
#DataFrame.new(DataFrame.Table.build_random(6,4), [1,3,4,5], DataFrame.DateRange.new("2016-09-12", 6) )
